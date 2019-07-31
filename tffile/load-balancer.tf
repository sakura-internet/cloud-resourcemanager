### 概要
# ロードバランサー利用のサンプルテンプレート
#
# このテンプレートはWebサーバを2台構成してLBにて負荷分散する構成です。
# ホスト名やrootパスワードの設定などは"構成構築"タブ内をご覧ください。
# ※SandboxではVPCルータの設定変更がされないなど正常に完了しません。
#
# -----------------------------------------------
# 変数定義(パスワード、ホスト名など)
# -----------------------------------------------
# サーバパスワード
variable "server_password" {
  default = "your-password"
}

# サーバ1のホスト名
variable "server01_hostname" {
  default = "your-hostname1"
}

# サーバ2のホスト名
variable "server02_hostname" {
  default = "your-hostname2"
}

### 構成構築
# -----------------------------------------------
# スイッチ+ルーター
# -----------------------------------------------
resource "sakuracloud_internet" "router" {
  name = "wan_switch"
}

resource "sakuracloud_load_balancer" "lb" {
  switch_id         = sakuracloud_internet.router.switch_id
  high_availability = false
  plan              = "standard"

  vrid          = 1
  ipaddress1    = sakuracloud_internet.router.ipaddresses[0]
  ipaddress2    = sakuracloud_internet.router.ipaddresses[1]
  nw_mask_len   = sakuracloud_internet.router.nw_mask_len
  default_route = sakuracloud_internet.router.gateway
  name          = "load_balancer"
}

# -----------------------------------------------
# VIP(ロードバランサーの設定)
# -----------------------------------------------
resource "sakuracloud_load_balancer_vip" "vip1" {
  load_balancer_id = sakuracloud_load_balancer.lb.id
  vip              = sakuracloud_internet.router.ipaddresses[2]
  port             = 80
  delay_loop       = 10
  sorry_server     = sakuracloud_internet.router.ipaddresses[3]
}

# -----------------------------------------------
# サーバー(ロードバランサーの設定)
# -----------------------------------------------
# サーバー1
resource "sakuracloud_load_balancer_server" "server01" {
  load_balancer_vip_id = sakuracloud_load_balancer_vip.vip1.id
  ipaddress            = sakuracloud_internet.router.ipaddresses[4]
  check_protocol       = "http"
  check_path           = "/"
  check_status         = "200"
}

# サーバー2
resource "sakuracloud_load_balancer_server" "server02" {
  load_balancer_vip_id = sakuracloud_load_balancer_vip.vip1.id
  ipaddress            = sakuracloud_internet.router.ipaddresses[5]
  check_protocol       = "http"
  check_path           = "/"
  check_status         = "200"
}

# ----------------------------------------------------------
# スタートアップスクリプト(DSR構成のためにループバックアドレス設定)
# パブリックスクリプト"lb-dsr"を参照
# ----------------------------------------------------------
resource "sakuracloud_note" "lb_dsr" {
  name    = "lb_dsr"
  content = <<EOF
PARA1="${sakuracloud_internet.router.ipaddresses[2]}"
PARA2="net.ipv4.conf.all.arp_ignore = 1"
PARA3="net.ipv4.conf.all.arp_announce = 2"
PARA4="DEVICE=lo:0"
PARA5="IPADDR="$PARA1
PARA6="NETMASK=255.255.255.255"

VERSION=$(rpm -q centos-release --qf %%{VERSION}) || exit 1

case "$VERSION" in
  6 ) ;;
  7 ) firewall-cmd --add-service=http --zone=public --permanent
      firewall-cmd --reload;;
  * ) ;;
esac

cp --backup /etc/sysctl.conf /tmp/ || exit 1

echo $PARA2 >> /etc/sysctl.conf
echo $PARA3 >> /etc/sysctl.conf
sysctl -p 1>/dev/null

cp --backup /etc/sysconfig/network-scripts/ifcfg-lo:0 /tmp/ 2>/dev/null

touch /etc/sysconfig/network-scripts/ifcfg-lo:0
echo $PARA4 > /etc/sysconfig/network-scripts/ifcfg-lo:0
echo $PARA5 >> /etc/sysconfig/network-scripts/ifcfg-lo:0
echo $PARA6 >> /etc/sysconfig/network-scripts/ifcfg-lo:0

ifup lo:0 || exit 1

exit 0
EOF

}

# ----------------------------------------------------------
# サーバーへのWebサーバー(httpd)インストール
# ----------------------------------------------------------
resource "sakuracloud_note" "install_httpd" {
  name = "install_httpd"
  content = <<EOF
yum install -y httpd || exit 1
echo 'This is a TestPage!!' >> /var/www/html/index.html || exit1
systemctl enable httpd.service || exit 1
systemctl start httpd.service || exit 1
firewall-cmd --add-service=http --zone=public --permanent || exit 1

exit 0
EOF

}

# ----------------------------------------------------------
# サーバーで利用するパブリックアーカイブ(CentOS7)
# ----------------------------------------------------------
data "sakuracloud_archive" "centos" {
os_type = "centos" // "ubuntu" を指定するとUbuntuの最新安定版パブリックアーカイブ
}

# ----------------------------------------------------------
# サーバー1
# ----------------------------------------------------------
resource "sakuracloud_disk" "disk01" {
name              = "disk01"                           // ディスク名の指定
plan              = "ssd"                              // プランの指定
size              = 40                                 // 容量指定(GB)
source_archive_id = data.sakuracloud_archive.centos.id // アーカイブの設定
}

resource "sakuracloud_server" "server01" {
name        = "server01"
disks       = [sakuracloud_disk.disk01.id]
nic         = sakuracloud_internet.router.switch_id
ipaddress   = sakuracloud_internet.router.ipaddresses[4]
gateway     = sakuracloud_internet.router.gateway
nw_mask_len = sakuracloud_internet.router.nw_mask_len

core   = 2
memory = 2

hostname = var.server01_hostname
password = var.server_password
note_ids = [sakuracloud_note.lb_dsr.id, sakuracloud_note.install_httpd.id]
}

# ----------------------------------------------------------
# サーバー2
# ----------------------------------------------------------
resource "sakuracloud_disk" "disk02" {
name              = "disk02"                           // ディスク名の指定
plan              = "ssd"                              // プランの指定
size              = 40                                 // 容量指定(GB)
source_archive_id = data.sakuracloud_archive.centos.id // アーカイブの設定
}

resource "sakuracloud_server" "server02" {
name        = "server02"
disks       = [sakuracloud_disk.disk02.id]
nic         = sakuracloud_internet.router.switch_id
ipaddress   = sakuracloud_internet.router.ipaddresses[5]
gateway     = sakuracloud_internet.router.gateway
nw_mask_len = sakuracloud_internet.router.nw_mask_len

core   = 2
memory = 2

hostname = var.server02_hostname
password = var.server_password
note_ids = [sakuracloud_note.lb_dsr.id, sakuracloud_note.install_httpd.id]
}

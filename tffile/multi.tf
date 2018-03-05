### 概要
# DBやNFSアプライアンスも利用した複合構成を構築するサンプルテンプレート
#
# このテンプレートはWebサーバを2台構成してLBにて負荷分散になっています。
# また、DBアプライアンスを利用してDBを構築します。
# ローカル側にはVPCルータを経由しL2TP-IPSecで接続する構成です。
# ローカルサーバはファイルサーバとして利用を想定してNFSアプライアンスを構築します。
#
# ホスト名やrootパスワードの設定などは"構成構築"タブ内をご覧ください。
# WebサーバのローカルIPはリモートコンソールより手動での設定をお願いします。
#
# 構成
# Webサーバ×2台、DBアプライアンス×1台、RT+SW×1台、SW×1台、LB×1台
# VPCルータ×1台、Fileサーバ×1台、NFS×1台
#
# -----------------------------------------------
# 変数定義
# -----------------------------------------------
# L2TP/IPSec 事前共有キー
variable pre_shared_secret { default = "PutYourSecret" }
# L2TP/IPSec ユーザー名/パスワード
variable vpn_username { default = "PutYourName" }
variable vpn_password { default = "PutYourPassword" }
# サーバー管理者パスワード
variable server_password { default = "PutYourPassword" }
# Webサーバ1のホスト名
variable server01_hostname {default = "your-hostname1"}
# Webサーバ2のホスト名
variable server02_hostname {default = "your-hostname2"}
# Fileサーバのホスト名
variable file_hostname {default = "file-hostname"}
### 構成構築
# -----------------------------------------------
# スイッチ+ルーター+VPCルーター
# -----------------------------------------------
resource "sakuracloud_internet" "router" {
    name = "wan_switch"
}
resource "sakuracloud_load_balancer" "lb" {
    switch_id = "${sakuracloud_internet.router.switch_id}"
    high_availability = false
    plan = "standard"

    vrid = 1
    ipaddress1 = "${sakuracloud_internet.router.ipaddresses.0}"
    ipaddress2 = "${sakuracloud_internet.router.ipaddresses.1}"
    nw_mask_len = "${sakuracloud_internet.router.nw_mask_len}"
    default_route = "${sakuracloud_internet.router.gateway}"
    name = "load_balancer"
}
resource sakuracloud_switch "sw01" {
    name = "lacal_switch"
}
resource "sakuracloud_vpc_router" "vpc" {
    name = "vpc_router"
}
resource "sakuracloud_vpc_router_interface" "eth1"{
    vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
    index = 1
    switch_id = "${sakuracloud_switch.sw01.id}"
    ipaddress = ["192.168.100.1"]                   // VPCルータIPアドレスの設定
    nw_mask_len = 24                                // ネットワークマスク
}
resource "sakuracloud_vpc_router_l2tp" "l2tp" {
    vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
    vpc_router_interface_id = "${sakuracloud_vpc_router_interface.eth1.id}"

    pre_shared_secret = "${var.pre_shared_secret}"
    range_start = "192.168.100.251"                 // IPアドレス動的割り当て範囲(開始)
    range_stop = "192.168.100.254"                  // IPアドレス動的割り当て範囲(終了)
}
resource "sakuracloud_vpc_router_user" "user1" {
    vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
    name = "${var.vpn_username}"
    password = "${var.vpn_password}"
}
resource "sakuracloud_vpc_router_port_forwarding" "forward_http" {
    vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
    vpc_router_interface_id = "${sakuracloud_vpc_router_interface.eth1.id}"
    protocol = "tcp"
    global_port = 80
    private_address = "192.168.100.101"
    private_port = 80
}
resource "sakuracloud_vpc_router_port_forwarding" "forward_https" {
    vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
    vpc_router_interface_id = "${sakuracloud_vpc_router_interface.eth1.id}"

    protocol = "tcp"
    global_port = 443
    private_address = "192.168.100.101"
    private_port = 443
}
# -----------------------------------------------
# ロードバランサーの設定
# -----------------------------------------------
resource "sakuracloud_load_balancer_vip" "vip1" {
    load_balancer_id = "${sakuracloud_load_balancer.lb.id}"
    vip = "${sakuracloud_internet.router.ipaddresses.2}"
    port = 80
    delay_loop = 10
    sorry_server = "${sakuracloud_internet.router.ipaddresses.3}"
}
resource "sakuracloud_load_balancer_server" "server01"{
    load_balancer_vip_id = "${sakuracloud_load_balancer_vip.vip1.id}"
    ipaddress = "${sakuracloud_internet.router.ipaddresses.4}"
    check_protocol = "ping"
}
resource "sakuracloud_load_balancer_server" "server02"{
    load_balancer_vip_id = "${sakuracloud_load_balancer_vip.vip1.id}"
    ipaddress = "${sakuracloud_internet.router.ipaddresses.5}"
    check_protocol = "ping"
}
resource "sakuracloud_note" "lb_dsr" {
    name = "lb_dsr"
    content = <<EOF
PARA1="${sakuracloud_internet.router.ipaddresses.2}"
PARA2="net.ipv4.conf.all.arp_ignore = 1"
PARA3="net.ipv4.conf.all.arp_announce = 2"
PARA4="DEVICE=lo:0"
PARA5="IPADDR="$PARA1
PARA6="NETMASK=255.255.255.255"

VERSION=$(rpm -q centos-release --qf %{VERSION}) || exit 1

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
data sakuracloud_archive "centos" {
    os_type = "centos"
}
# ----------------------------------------------------------
# パケットフィルタの設定
# ----------------------------------------------------------
resource sakuracloud_packet_filter "www" {
    name = "www"
    expressions = {
        protocol    = "tcp"
        source_port = "0-65535"
        dest_port   = "80"
        allow       = true
    }
    expressions = {
        protocol    = "tcp"
        source_port = "0-65535"
        dest_port   = "443"
        allow       = true
    }
    expressions = {
        protocol    = "icmp"
        source_nw   = "${sakuracloud_internet.router.ipaddresses.0}"
        allow       = true
    }
    expressions = {
        protocol    = "ip"
        source_nw   = "0.0.0.0/0"
        allow       = false
        description = "Deny all"
    }
}
# ----------------------------------------------------------
# サーバー構築
# ----------------------------------------------------------
resource "sakuracloud_disk" "disk01"{
    name = "disk01"
    plan      = "ssd"
    size      = 40
    source_archive_id = "${data.sakuracloud_archive.centos.id}"
    hostname = "${var.server01_hostname}"
    password = "${var.server_password}"
    note_ids = ["${sakuracloud_note.lb_dsr.id}" , "${sakuracloud_note.install_httpd.id}"]
}
resource "sakuracloud_server" "web-server01" {
    name = "web-server01"
    disks = ["${sakuracloud_disk.disk01.id}"]
    nic = "${sakuracloud_internet.router.switch_id}"
    ipaddress = "${sakuracloud_internet.router.ipaddresses.4}"
    gateway = "${sakuracloud_internet.router.gateway}"
    nw_mask_len = "${sakuracloud_internet.router.nw_mask_len}"
    packet_filter_ids = ["${sakuracloud_packet_filter.www.id}"]
    additional_nics = ["${sakuracloud_switch.sw01.id}"]
    core = 2
    memory = 2
}
resource "sakuracloud_disk" "disk02"{
    name = "disk02"
    plan      = "ssd"
    size      = 40
    source_archive_id = "${data.sakuracloud_archive.centos.id}"

    hostname = "${var.server02_hostname}"
    password = "${var.server_password}"
    note_ids = ["${sakuracloud_note.lb_dsr.id}" , "${sakuracloud_note.install_httpd.id}"]
}
resource "sakuracloud_server" "web-server02" {
    name = "web-server02"
    disks = ["${sakuracloud_disk.disk02.id}"]
    nic = "${sakuracloud_internet.router.switch_id}"
    ipaddress = "${sakuracloud_internet.router.ipaddresses.5}"
    gateway = "${sakuracloud_internet.router.gateway}"
    nw_mask_len = "${sakuracloud_internet.router.nw_mask_len}"
    packet_filter_ids = ["${sakuracloud_packet_filter.www.id}"]
    additional_nics = ["${sakuracloud_switch.sw01.id}"]
    
    core = 2
    memory = 2
}
resource "sakuracloud_disk" "disk03"{
    name = "disk03"
    plan      = "ssd"
    size      = 40
    source_archive_id = "${data.sakuracloud_archive.centos.id}"
    hostname = "${var.file_hostname}"
    password = "${var.server_password}"
    note_ids = ["${sakuracloud_note.lb_dsr.id}" , "${sakuracloud_note.install_httpd.id}"]
}
resource "sakuracloud_server" "file-server" {
    name = "file-server"
    disks = ["${sakuracloud_disk.disk03.id}"]
    nic = "${sakuracloud_switch.sw01.id}"
    ipaddress = "192.168.100.101"
    nw_mask_len = 24
    gateway = "192.168.100.250"
    core = 2
    memory = 2
}
# ----------------------------------------------------------
# データベースアプライアンス
# ----------------------------------------------------------
resource sakuracloud_database "webdb" {
    database_type = "mariadb"
    plan          = "30g"
    user_name     = "dbusername"    // データベース接続用アカウント
    user_password = "${var.server_password}"
    port = 3306
    backup_time = "00:00"
    switch_id     = "${sakuracloud_switch.sw01.id}"
    ipaddress1    = "192.168.100.11"
    nw_mask_len   = 24
    default_route = "192.168.100.250"
    name = "webdb"
}
# ----------------------------------------------------------
# NFSアプライアンス
# ----------------------------------------------------------
resource sakuracloud_nfs "fs" {
    name = "fs"
    switch_id = "${sakuracloud_switch.sw01.id}"
    plan = "500"    // プラン[100/500/1024(1T)/2048(2T)/4096(4T)]
    ipaddress = "192.168.100.102"
    nw_mask_len = 24
    default_route = "192.168.100.250"
}

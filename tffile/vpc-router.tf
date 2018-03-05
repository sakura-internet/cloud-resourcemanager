### 概要
#
# VPCルータ利用のサンプルテンプレート
#
# VPCルータを設置し、サーバに対してHTTPとHTTPSのみインターネットからの接続を許可します。
# そのほかの通信に関してはL2TP/IPSecにて接続することにより可能となります。
#
# <構築手順>
#   1) tffile編集画面の"変数定義"タブにて以下の値を編集します。
#      - L2TP/IPSec 事前共有キー(pre_shared_secret)
#      - L2TP/IPSec ユーザー名(vpn_username)
#      - L2TP/IPSec パスワード(vpn_password)
#      - サーバ管理者のパスワード(server_password)
#
#      ※ 上記以外の変数については必要に応じて編集してください。
#
#   2) リソースマネージャー画面にて"計画/反映"を実行します。
#
# リソースの各設定などは各リソースのタブ内をご覧ください。
# ※SandboxではVPCルータの設定変更がされないなど正常に完了しません。
#
### 変数定義
locals {
  #**********************************************
  # ユーザー名/パスワード/事前共有キーなど
  #**********************************************
  # L2TP/IPSec 事前共有キー
  pre_shared_secret = "<put-your-secret>" # < 変更してください

  # L2TP/IPSec ユーザー名/パスワード
  vpn_username = "<put-your-name>"        # < 変更してください
  vpn_password = "<put-your-password>"    # < 変更してください

  # サーバー管理者パスワード
  server_password = "<put-your-root-password>" # < 変更してください

  #**********************************************
  # スペックなど(必要に応じて変更してください)
  #**********************************************
  # スイッチ名
  switch_name = "local-sw"

  # VPCルータ名
  vpc_router_name = "vpc-router"

  # VPCルータのプライベート側NICのIPアドレス/マスク長
  vpc_router_eth1_ip       = "192.168.100.1"
  vpc_router_eth1_mask_len = 24

  # L2TPで割り当てるIPアドレス範囲
  l2tp_range_start = "192.168.100.251" # 開始アドレス
  l2tp_range_stop  = "192.168.100.254" # 終了アドレス

  # サーバへのReverse NAT対象
  reverse_nat_targets = [
    {
      // for HTTP
      "protocol" = "tcp"
      "port"     = 80
    },
    {
      // for HTTPS
      "protocol" = "tcp"
      "port"     = 443
    },
  ]

  # サーバ関連
  server_name     = "web-server"           # サーバ名
  disk_name       = "${local.server_name}" # ディスク名
  server_ip       = "192.168.100.101"      # サーバ IPアドレス
  server_mask_len = 24                     # サーバ マスク長
  server_core     = 2                      # サーバ コア数
  server_memory   = 2                      # サーバ メモリサイズ(GB単位)
}

### VPCルータ
# VPCルータ
resource "sakuracloud_vpc_router" "vpc" {
  name = "${local.vpc_router_name}" # VPCルータ名
}

# VPCルータ プライベート側NIC(eth1)
resource "sakuracloud_vpc_router_interface" "eth1" {
  vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
  index         = 1
  switch_id     = "${sakuracloud_switch.sw01.id}"
  ipaddress     = ["${local.vpc_router_eth1_ip}"]     # VPCルータIPアドレスの設定
  nw_mask_len   = "${local.vpc_router_eth1_mask_len}" # ネットワークマスク
}

# L2TP
resource "sakuracloud_vpc_router_l2tp" "l2tp" {
  vpc_router_id           = "${sakuracloud_vpc_router.vpc.id}"
  vpc_router_interface_id = "${sakuracloud_vpc_router_interface.eth1.id}"
  pre_shared_secret       = "${local.pre_shared_secret}"
  range_start             = "${local.l2tp_range_start}"                   # IPアドレス動的割り当て範囲(開始)
  range_stop              = "${local.l2tp_range_stop}"                    # IPアドレス動的割り当て範囲(終了)
}

# リモートアクセス(L2TP) ユーザー
resource "sakuracloud_vpc_router_user" "user1" {
  vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
  name          = "${local.vpn_username}"
  password      = "${local.vpn_password}"
}

# グローバル側からプライベート側へのReverse NAT
resource "sakuracloud_vpc_router_port_forwarding" "forward_rules" {
  vpc_router_id           = "${sakuracloud_vpc_router.vpc.id}"
  vpc_router_interface_id = "${sakuracloud_vpc_router_interface.eth1.id}"

  count = "${length(local.reverse_nat_targets)}"

  protocol        = "${lookup(local.reverse_nat_targets[count.index], "protocol")}"
  private_address = "${local.server_ip}"
  global_port     = "${lookup(local.reverse_nat_targets[count.index], "port")}"
  private_port    = "${lookup(local.reverse_nat_targets[count.index], "port")}"
}

### スイッチ
resource "sakuracloud_switch" "sw01" {
  name = "${local.switch_name}"
}

### サーバ/ディスク

# コピー元アーカイブ(CentOS7)
data sakuracloud_archive "centos" {
  os_type = "centos"
}

# ディスク
resource "sakuracloud_disk" "disk01" {
  name              = "${local.disk_name}"
  source_archive_id = "${data.sakuracloud_archive.centos.id}"
  password          = "${local.server_password}"
}

# サーバ
resource sakuracloud_server "server01" {
  name   = "${local.server_name}"
  core   = "${local.server_core}"
  memory = "${local.server_memory}"
  disks  = ["${sakuracloud_disk.disk01.id}"]

  nic         = "${sakuracloud_switch.sw01.id}" # スイッチに接続
  ipaddress   = "${local.server_ip}"
  nw_mask_len = "${local.server_mask_len}"
  gateway     = "${local.vpc_router_eth1_ip}"
}


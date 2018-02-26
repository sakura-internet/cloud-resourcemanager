### 概要
# VPCルータ利用のサンプルテンプレート
#
# VPCルータを設置し、サーバに対してHTTPとHTTPSのみインターネットからの接続を許可します。
# そのほかの通信に関してはL2TP/IPSecにて接続することにより可能となります。
# 
# リソースの各設定などは"構成構築"タブ内をご覧ください。
# ※SandboxではVPCルータの設定変更がされないなど正常に完了しません。
# -----------------------------------------------
# 変数定義(ログイン情報など)
# -----------------------------------------------
# L2TP/IPSec 事前共有キー
variable pre_shared_secret { default = "PutYourSecret" }
# L2TP/IPSec ユーザー名/パスワード
variable vpn_username { default = "PutYourName" }
variable vpn_password { default = "PutYourPassword" }
# サーバー管理者パスワード
variable server_password { default = "PutYourPassword" }

### 構成構築
# -----------------------------------------------
# VPCルーター+スイッチ
# -----------------------------------------------
resource "sakuracloud_switch" "sw01"{
    name = "local-sw"                                   // スイッチ名
}

resource "sakuracloud_vpc_router" "vpc" {
    name = "vpc_router"                             // VPCルータ名
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
# ポートフォワード(Reverse NAT) : HTTP
    protocol = "tcp"
    global_port = 80
    private_address = "192.168.100.101"
    private_port = 80
}
# ポートフォワード(Reverse NAT) : HTTPS
resource "sakuracloud_vpc_router_port_forwarding" "forward_https" {
    vpc_router_id = "${sakuracloud_vpc_router.vpc.id}"
    vpc_router_interface_id = "${sakuracloud_vpc_router_interface.eth1.id}"

    protocol = "tcp"
    global_port = 443
    private_address = "192.168.100.101"
    private_port = 443
}

# -----------------------------------------------------------------------------
# Webサーバーの定義
# -----------------------------------------------------------------------------
data sakuracloud_archive "centos" {
    filter = {
        name   = "Tags"
        values = ["current-stable", "arch-64bit", "distro-centos"]
    }
}
resource "sakuracloud_disk" "disk01" {
    name = "disk"
    source_archive_id = "${data.sakuracloud_archive.centos.id}"
    password = "${var.server_password}"
}
resource sakuracloud_server "server01" {
    name = "web_server"
    disks = ["${sakuracloud_disk.disk01.id}"]

    nic = "${sakuracloud_switch.sw01.id}"
    ipaddress = "192.168.100.101"
    gateway = "192.168.100.1"
    nw_mask_len = 24

    core = 2
    memory = 2
}

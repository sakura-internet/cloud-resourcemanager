### 概要
# サーバ作成及びシンプル監視のサンプルテンプレート
# このテンプレートはサーバを1台作成してシンプル監視を使用してpingにて
# 死活監視を行います。
# ホスト名やrootパスワードの設定などは"構成構築"タブ内をご覧ください。
# ※Sandboxではシンプル監視のリソースは作成されません。
### 構成構築
# ----------------------------------------------------------
# サーバーで利用するパブリックアーカイブ(CentOS7)
# ----------------------------------------------------------
data sakuracloud_archive "centos" {
    os_type = "centos"          // "ubuntu" を指定するとUbuntuの最新安定版パブリックアーカイブ
}
# ----------------------------------------------------------
# サーバー
# ----------------------------------------------------------
# ディスク作成
resource "sakuracloud_disk" "disk01"{
    name = "disk01"             // ディスク名の指定
    plan      = "ssd"           // プランの指定
    size      = 40              // 容量指定(GB)
    source_archive_id = "${data.sakuracloud_archive.centos.id}" // アーカイブの設定
}
# VM作成
resource "sakuracloud_server" "server01" {
    name = "server01"           // サーバ名の指定
    disks = ["${sakuracloud_disk.disk01.id}"]
    nic = "shared"              // 共有セグメントに接続
    core = 2                    // CPUコアの指定
    memory = 2                  // メモリ容量の指定

    hostname = "your-host-name" // ホスト名の設定
    password = "your-password"  // rootパスワードの設定
}

# ----------------------------------------------------------
# シンプル監視
# ----------------------------------------------------------
# ping監視の例
resource sakuracloud_simple_monitor "mymonitor" {
  target = "${sakuracloud_server.server01.ipaddress}"

  health_check = {
    protocol   = "ping"
  }

  notify_email_enabled = true
  enabled              = true
}

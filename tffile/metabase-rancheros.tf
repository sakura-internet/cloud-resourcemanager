### 概要
#
# データベースアプライアンス(PostgreSQL)とRancherOSでMetabase実行環境を構築するテンプレート
#
# このテンプレートはRancherOS上のDockerでMetabaseを実行する構成となっています。
# Metabaseのバックエンドとしてデータベースアプライアンス(PostgreSQL)を利用します。
#
# ※このテンプレートは石狩第2ゾーン/東京第1ゾーンでのみご利用いただけます。
#
# <事前準備>
#
#   - さくらのクラウド上にSSH用の公開鍵を登録しておきます。
#     参考: https://manual.sakura.ad.jp/cloud/controlpanel/settings/public-key.html#id5
#
# <構築手順>
#
#   1) tffile編集画面の"変数定義"タブにて以下の値を編集します。
#      - サーバ管理者のパスワード(server_password)
#      - データベース接続ユーザーのパスワード(database_password)
#      - さくらのクラウドに登録済みの公開鍵の名称(ssh_public_key_name)
#   2) リソースマネージャー画面にて"計画/反映"を実行
#
# <動作確認>
#
#   ブラウザから以下のURLにアクセスするとMetabaseの画面が開きます。
#      http://<作成したサーバーのグローバルIPアドレス>/
#
# <サーバへのSSH接続>
#
#   サーバへのSSH接続は、指定した公開鍵による公開鍵認証のみ許可されるようになっています。
#   デバッグなどでSSH接続を行う際は秘密鍵を指定して接続してください。
#
#   > usacloudでのSSH接続例
#   $ usacloud server ssh -i <your-private-key-file> <your-server-name>
#
# SSH接続後はdocker logsコマンドなどでMetabaseコンテナのログを確認可能です。
#
### 変数定義
locals {
  #*********************************************
  # パスワード/公開鍵関連(要変更)
  #*********************************************
  # サーバ管理者のパスワード
  server_password = "<put-your-password-here>"

  # データベース接続ユーザーのパスワード
  database_password = "<put-your-password-here>"

  # さくらのクラウドに登録済みの公開鍵の名称
  ssh_public_key_name = "<put-your-public-key-name>"

  #*********************************************
  # サーバ/ディスク
  #*********************************************
  # サーバ名
  server_name = "metabase"

  # サーバホスト名
  host_name = local.server_name

  # サーバ コア数
  server_core = 2

  # サーバ メモリサイズ(GB)
  server_memory = 4

  # ディスクサイズ
  disk_size = 20

  #*********************************************
  # ネットワーク(スイッチ/パケットフィルタ)
  #*********************************************
  # スイッチ名
  switch_name = "metabase-internal"

  # パケットフィルタ名
  packet_filter_name = "metabase-filter"

  #*********************************************
  # データベースアプライアンス
  #*********************************************
  # データベースアプライアンス名
  database_name = "metabase-db"

  # プラン
  database_plan = "30g" # 10g/30g/90g/240g

  # 接続ユーザー名
  database_user_name = "metabase"

  # バックアップ時刻
  database_backup_time = "01:00"

  # バックアップ取得曜日
  database_backup_weekdays = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
}

### サーバ/ディスク

# パブリックアーカイブ(OS)のID参照用のデータソース(RancherOS)
data "sakuracloud_archive" "rancheros" {
  os_type = "rancheros"
}

# 公開鍵のID参照用のデータソース
data "sakuracloud_ssh_key" "ssh_public_key" {
  # TF-UPGRADE-TODO: In Terraform v0.10 and earlier, it was sometimes necessary to
  # force an interpolation expression to be interpreted as a list by wrapping it
  # in an extra set of list brackets. That form was supported for compatibilty in
  # v0.11, but is no longer supported in Terraform v0.12.
  #
  # If the expression in the following list itself returns a list, remove the
  # brackets to avoid interpretation as a list of lists. If the expression
  # returns a single list item then leave it as-is and remove this TODO comment.
  name_selectors = [local.ssh_public_key_name]
}

# ディスク
resource "sakuracloud_disk" "disk" {
  name              = local.server_name
  source_archive_id = data.sakuracloud_archive.rancheros.id

  lifecycle {
    ignore_changes = [source_archive_id]
  }
}

# サーバ
resource "sakuracloud_server" "server" {
  name              = local.server_name
  disks             = [sakuracloud_disk.disk.id]
  core              = local.server_core
  memory            = local.server_memory
  packet_filter_ids = [sakuracloud_packet_filter.filter.id]
  additional_nics   = [sakuracloud_switch.sw.id]

  hostname        = local.host_name
  password        = local.server_password
  note_ids        = [sakuracloud_note.provisioning.id]
  ssh_key_ids     = [data.sakuracloud_ssh_key.ssh_public_key.id]
  disable_pw_auth = true
}

# スタートアップスクリプト(IP設定、metabaseコンテナ起動)
resource "sakuracloud_note" "provisioning" {
  name  = "provisioning-metabase"
  class = "yaml_cloud_config"

  content = <<EOF
#cloud-config
rancher:
  console: default
  docker:
    engine: docker-17.09.1-ce
  network:
    interfaces:
      eth1:
        address: 192.168.100.10/28
        dhcp: false
  services:
    metabase:
      image: metabase/metabase:latest
      ports:
        - "80:3000"
      environment:
        MB_DB_TYPE: postgres
        MB_DB_DBNAME: ${local.database_user_name}
        MB_DB_PORT: 5432
        MB_DB_USER: ${local.database_user_name}
        MB_DB_PASS: ${local.database_password}
        MB_DB_HOST: 192.168.100.2
      restart: always
EOF

}

### データベースアプライアンス
resource "sakuracloud_database" "db" {
  name = local.database_name

  database_type = "postgresql"
  plan = local.database_plan

  user_name = local.database_user_name
  user_password = local.database_password

  allow_networks = ["192.168.100.0/28"]
  port = 5432
  backup_time = local.database_backup_time
  backup_weekdays = local.database_backup_weekdays

  switch_id = sakuracloud_switch.sw.id
  ipaddress1 = "192.168.100.2"
  nw_mask_len = 28
  default_route = "192.168.100.1"
}

### パケットフィルタ
resource "sakuracloud_packet_filter" "filter" {
  name = local.packet_filter_name

  expressions {
    protocol = "tcp"
    dest_port = "22"
    description = "Allow external:SSH"
  }

  expressions {
    protocol = "tcp"
    dest_port = "80"
    description = "Allow external:HTTP"
  }

  expressions {
    protocol = "icmp"
  }

  expressions {
    protocol = "fragment"
  }

  expressions {
    protocol = "udp"
    source_port = "123"
  }

  expressions {
    protocol = "tcp"
    dest_port = "32768-61000"
    description = "Allow from server"
  }

  expressions {
    protocol = "udp"
    dest_port = "32768-61000"
    description = "Allow from server"
  }

  expressions {
    protocol = "ip"
    allow = false
    description = "Deny ALL"
  }
}

### スイッチ
resource "sakuracloud_switch" "sw" {
  name = local.switch_name
}


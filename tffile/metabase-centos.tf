### 概要
#
# データベースアプライアンス(PostgreSQL)とCentOS7でMetabase実行環境を構築するテンプレート
#
# このテンプレートはCentOS7上のDockerでMetabaseを実行する構成となっています。
# Metabaseのバックエンドとしてデータベースアプライアンス(PostgreSQL)を利用します。
#
# ※このテンプレートは石狩第2ゾーン/東京第1ゾーンでのみご利用いただけます。
#
# <構築手順>
#   1) tffile編集画面の"変数定義"タブにて以下の値を編集します。
#      - サーバ管理者のパスワード(server_password)
#      - データベース接続ユーザーのパスワード(database_password)
#
#   2) リソースマネージャー画面にて"計画/反映"を実行します。
#
# <動作確認>
#
# ブラウザから以下のURLにアクセスするとMetabaseの画面が開きます。
#    http://<作成したサーバーのグローバルIPアドレス>/
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

# パブリックアーカイブ(OS)のID参照用のデータソース(CentOS7)
data "sakuracloud_archive" "centos" {
  os_type = "centos"
}

# ディスク
resource "sakuracloud_disk" "disk" {
  name              = local.server_name
  source_archive_id = data.sakuracloud_archive.centos.id

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

  hostname = local.host_name
  password = local.server_password
  note_ids = [sakuracloud_note.provisioning.id]
}

# スタートアップスクリプト(Dockerインストール、IP設定、metabaseコンテナ起動)
resource "sakuracloud_note" "provisioning" {
  name  = "provisioning-metabase"
  class = "shell"

  content = <<EOF
#!/bin/sh

# @sacloud-name "Metabase"
# @sacloud-once
# @sacloud-desc-begin
# このスクリプトはMetabaseサーバをセットアップします
# (このスクリプトは、CentOS7.Xでのみ動作します)
# @sacloud-desc-end
#
# @sacloud-require-archive distro-centos distro-ver-7

set -x
yum update -y

# eth1へのIPアドレス設定
nmcli con mod "System eth1" \
  ipv4.method manual \
  ipv4.address "192.168.100.10/28" \
  connection.autoconnect "yes" \
  ipv6.method ignore
nmcli con down "System eth1"; nmcli con up "System eth1"

# Dockerのインストール
curl -fsSL https://get.docker.com/ | sh
systemctl enable docker.service
systemctl start docker.service

# Docker上でMetabaseを起動
cat > /root/run-metabase.sh <<EOL
#!/bin/sh
docker run -d -p 80:3000 \
           -e MB_DB_TYPE=postgres \
           -e MB_DB_DBNAME="${local.database_user_name}" \
           -e MB_DB_PORT=5432 \
           -e MB_DB_USER="${local.database_user_name}" \
           -e MB_DB_PASS="${local.database_password}" \
           -e MB_DB_HOST="192.168.100.2" \
           --restart=always \
           metabase/metabase:latest
EOL

chmod +x /root/run-metabase.sh
/root/run-metabase.sh

# Firewall設定
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --reload

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

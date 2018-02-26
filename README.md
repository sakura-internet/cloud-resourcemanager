さくらのクラウド リソースマネージャー
====

リソースマネージャーは、コントロールパネルの操作だけでリソースを一括して作成・更新・削除できる機能です。複数のリソースをテンプレートで一元管理できます。本機能のテンプレートは HashiCorp が提供する Terraform の構成情報と一部に互換性があります。
さくらインターネットが提供しているパブリックスクリプトの一覧です。

詳細は[さくらのクラウドマニュアル](https://manual.sakura.ad.jp/cloud/resource-manager/)をご参照ください

# 提供中のtfファイル

* [基本構成](#basic)
* [応用例](#application)

## <a name="basic">基本構成例</a>

| 名前 | 説明 |
| --- | :--- |
| [サーバ作成及びシンプル監視する構成](./tffile/server.tf) | このテンプレートはサーバを1台作成してシンプル監視を使用してpingにて死活監視を行います。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/server.html) をご覧ください。  |
| [VPC ルータを設置し、配下にサーバを構築する構成](./tffile/vpc-router.tf) | VPCルータを設置し、サーバに対してHTTPとHTTPSのみインターネットからの接続を許可します。そのほかの通信に関してはL2TP/IPSecにて接続することにより可能となります。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/vpc-router.html) をご覧ください。  |
| [Webサーバを2台構築し、ロードバランサで冗長化する構成](./tffile/load-balancer.tf) | ロードバランサ・アプライアンスと、Webサーバを2台構成してLBにて負荷分散する構成です。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/load-balancer.html) をご覧ください。  |

## <a name="development">応用例</a>

| 名前 | 説明 |
| --- | :--- |
| [DBやNFSアプライアンスも利用した複合構成を構築](./tffile/multi.tf) | Webサーバを2台構成してLBにて負荷分散になっています。また、DBアプライアンスを利用してDBを構築します。ローカル側にはVPCルータを経由しL2TP-IPSecで接続する構成です。ローカルサーバはファイルサーバとして利用を想定してNFSアプライアンスを構築します。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/multi.html) をご覧ください。  |
| [Metabaseを構築する構成(CentOS7バージョン)](./tffile/metabase-centos.tf) | このテンプレートはCentOS7上のDockerでMetabaseを実行する構成となっています。Metabaseのバックエンドとしてデータベースアプライアンス(PostgreSQL)を利用します。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/metabase.html) をご覧ください。  |
| [Metabaseを構築する構成(RancherOSバージョン)](./tffile/metabase-rancheros.tf) | このテンプレートはRancherOS上のDockerでMetabaseを実行する構成となっています。Metabaseのバックエンドとしてデータベースアプライアンス(PostgreSQL)を利用します。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/metabase.html) をご覧ください。  |

構文は [Terraform for さくらのクラウド ドキュメント](https://sacloud.github.io/terraform-provider-sakuracloud/) をご覧ください。

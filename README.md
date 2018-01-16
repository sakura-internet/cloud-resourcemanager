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
| [サーバ作成及びシンプル監視する構成]() | このテンプレートはサーバを1台作成してシンプル監視を使用してpingにて死活監視を行います。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/server.html) をご覧ください。  |
| [VPC ルータを設置し、配下にサーバを構築する構成]() | VPCルータを設置し、サーバに対してHTTPとHTTPSのみインターネットからの接続を許可します。そのほかの通信に関してはL2TP/IPSecにて接続することにより可能となります。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/vpc-router.html) をご覧ください。  |
| [Webサーバを2台構築し、ロードバランサで冗長化する構成]() | ロードバランサ・アプライアンスと、Webサーバを2台構成してLBにて負荷分散する構成です。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/load-balancer.html) をご覧ください。  |

## <a name="development">応用例</a>

| 名前 | 説明 |
| --- | :--- |
| [DBやNFSアプライアンスも利用した複合構成を構築]() | Webサーバを2台構成してLBにて負荷分散になっています。また、DBアプライアンスを利用してDBを構築します。ローカル側にはVPCルータを経由しL2TP-IPSecで接続する構成です。ローカルサーバはファイルサーバとして利用を想定してNFSアプライアンスを構築します。詳しくは [ドキュメント](https://manual.sakura.ad.jp/cloud/resource-manager/templates/multi.html) をご覧ください。  |

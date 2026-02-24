コード生成用プロンプト

あなたは IaC のプロのインフラエンジニアです。
以下要件を満たす Terraform（HCL）一式 と、必要な補助スクリプトを生成してください。
目的は EC2 を4台作るだけで、OS内の構築は不要です。作成後に既存の 00_env.sh にIPを反映し、99_run_all.sh をローカルで実行できるようにします。

1. 実現したいこと

AWS 上で EC2 を4台自動構築する

役割: WEB, AP, DB, INNER_DNS

中身の構築（Apache/PHP/DB/DNS 等のインストール）は不要

サブネットは指定しない（= 既定VPC/既定サブネット等を利用して良い）

ただし「各サーバにパッケージなどをインストールできる」状態にする
→ 外部インターネットへのアウトバウンドが可能（Public IP 付与）

2. 必須要件（超重要）
2-1. EC2は4台

インスタンス名（Tag Name）と役割が分かるようにする

例: wp3tier-web, wp3tier-ap, wp3tier-db, wp3tier-inner-dns

2-2. 00_env.sh へ IP を渡す

既存の 00_env.sh のうち、以下の8変数だけを Terraform apply 後に自動で上書き更新すること:

WEB_PUBLIC_IP, AP_PUBLIC_IP, DB_PUBLIC_IP, INNER_DNS_PUBLIC_IP

WEB_PRIVATE_IP, AP_PRIVATE_IP, DB_PRIVATE_IP, INNER_DNS_PRIVATE_IP

00_env.sh 内のその他の変数（SSH_USER, SSH_KEY_PATH, WP_DB_NAME 等）は 保持すること

00_env.sh のファイルパスは Terraform 実行ディレクトリ直下の ./00_env.sh とする
（更新前にバックアップ必須：例 00_env.sh.bak_YYYYmmdd_HHMMSS）

2-3. EC2作成後に 99_run_all.sh を呼び出す

Terraform apply 完了後、上記の 00_env.sh が更新された状態で

./99_run_all.sh を ローカルで実行する仕組みを入れること

実行は「毎回必ず」ではなく、以下で制御できること：

var.run_after_apply（default false）

true のときだけ 99_run_all.sh を呼ぶ

3. セキュリティグループ要件（追加要件：厳守）

セキュリティグループは “役割ごとに分けて” 作成し、指定の参照関係で許可してください。
（例：WEB用SG, AP用SG, DB用SG, DNS用SG）

3-1. 4台共通（全SGに入れる共通ルール）

inbound: SSH 22/tcp を 自分のIP（var.my_ip_cidr） からのみ許可

outbound: all allow

3-2. WEB（WEB用SG）

inbound: HTTP 80/tcp を 自分のIP（var.my_ip_cidr） からのみ許可
※ 0.0.0.0/0は禁止（学習用でも今回は MyIP 限定）

3-3. AP（AP用SG）

inbound: TCP 9000 を WEBサーバのSGからの通信のみ許可（CIDRではなく source_security_group_id で参照）

3-4. DB（DB用SG）

inbound: MySQL 3306/tcp を APサーバのSGからの通信のみ許可（source_security_group_id 参照）

3-5. 内部DNS（DNS用SG）

inbound:

DNS 53/udp を 0.0.0.0/0 から許可

DNS 53/tcp は 自分のネットワーク（var.my_network_cidr） のみ許可

例: "192.168.0.0/24" のようなネットワークCIDR

※ SSH 22/tcp は共通ルールで MyIP 許可済み

4. 実装方針（指定）

Terraform は AWS Provider を使用

AMI は Amazon Linux 2023 を data source で取得（固定AMI IDは禁止）

既定VPC/既定サブネットを使って良いので subnet_id は指定しない

インスタンスは t3.micro をデフォルトにする（変数で変更可能に）

公開IPが付くこと（associate_public_ip_address = true など、既定サブネットの挙動に依存しすぎない）

出力（outputs）として各EC2の Public/Private IP を出す

5. 生成してほしい成果物

以下をすべて出力してください（ファイル単位でセクションを分けて提示）:

main.tf（provider, data, resources）

variables.tf

outputs.tf

versions.tf（required_version / required_providers）

scripts/update_env.sh

Terraform output（jsonでも可）からIPを取り出し、./00_env.sh の該当変数だけ sed/perl 等で更新する

バックアップ作成必須

README.md

terraform init/apply

run_after_apply の使い方

my_ip_cidr と my_network_cidr の指定例

注意点（mac/linux差分など）

6. 変数（必須）

最低限以下を変数化してください:

aws_region（default: ap-northeast-1）

instance_type（default: t3.micro）

ssh_key_name（既存のEC2 KeyPair名）

my_ip_cidr（例: "203.0.113.10/32"） ← SSHとWEB(80)で使う

my_network_cidr（例: "192.168.0.0/24"） ← DNS 53/tcp で使う

project_name（default: wp3tier）

run_after_apply（default: false）

7. 依存関係・冪等性

99_run_all.sh 実行は null_resource + local-exec を使って良い

ただし実行順が保証されるように：

update_env.sh → 99_run_all.sh の順

depends_on と triggers を適切に設計する（IPが変わった時に再実行されるなど）

8. 実行イメージ

terraform apply

apply の最後に scripts/update_env.sh が走って 00_env.sh が更新される

var.run_after_apply=true のときのみ ./99_run_all.sh が実行される

以上の要件で、Terraform一式と補助スクリプトを生成してください。
また、00_env.sh と 99_run_all.sh は既に存在し、99_run_all.sh は 00_env.sh を source して動作する前提です（書き換え不要、IPの注入のみ必要）。
## インストール状況確認
ターミナルで以下を実行。
```bash
terraform -version
aws --version
python3 --version
bash --version
```
---
</br>

## まず Homebrew があるか確認
```bash
brew --version
```
---
</br>

## Terraform をインストール（tenv経由）
```bash
brew update
brew install tenv
tenv terraform list-remote
tenv terraform install latest
tenv terraform use latest
terraform -version
```
`Terraform v1.5+` が出ればOK。

---
</br>

## AWS CLI をインストール（Homebrew）
```bash
brew install awscli
aws --version
```
`aws-cli/2.x ...` が出ればOK。

---
</br>

## （推奨）セキュリティ＆鍵用の補助も入れておくと楽
AWS周りだとよく使うのでついでに：
```bash
brew install jq
jq --version
```
※今回の update_env.sh は python3 でJSONを読むので jq 必須ではないです。

---
</br>

## インストール後の “疎通確認”
AWS 認証設定
```bash
aws configure
```
入力：
```bash
Access Key ID
Secret Access Key
Default region: ap-northeast-1
Default output format: json
```
確認：
```bash
aws sts get-caller-identity
```
▼ 実行結果
```bash
[kurosawamasaya@kurosawamasayanoMacBook-Pro ~]$ aws sts get-caller-identity
{
    "UserId": "AIDAZSPBUDHQTFS46TEIQ",
    "Account": "658140043745",
    "Arn": "arn:aws:iam::658140043745:user/masaya-terraform"
}
[kurosawamasaya@kurosawamasayanoMacBook-Pro ~]$ 
```
ここで Account/Arn が返れば AWS操作OK。


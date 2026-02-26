# wp3tier - EC2 4台 (WEB/AP/DB/INNER_DNS) Terraform

## 目的
- AWS 上に EC2 を4台自動構築する（OS内の構築は不要）
- `terraform apply` 後に `./00_env.sh` の8変数だけを自動更新（バックアップ作成）
- `var.run_after_apply=true` のときのみ `./99_run_all.sh` をローカル実行する
  - `99_run_all.sh` は `00_env.sh` を source して動作する前提

---
</br>
</br>


## 前提

- Terraform >= 1.5
- AWS認証情報（例: `aws configure` / 環境変数 / SSO 等）
- 既存EC2 KeyPair 名が必要（`ssh_key_name`）

---
</br>
</br>


## 使い方

### 1) 変数を用意（例: terraform.tfvars）

```hcl
aws_region      = "ap-northeast-1"
instance_type   = "t3.micro"
project_name    = "wp3tier"

ssh_key_name    = "YOUR_KEYPAIR_NAME"

# 自分のグローバルIP（/32）
my_ip_cidr      = "203.0.113.10/32"

# DNS TCP 53 を許可したい「自分のネットワークCIDR」
# 例: 自宅LANが 192.168.0.0/24 ならこれ
my_network_cidr = "192.168.0.0/24"

# apply後に 99_run_all.sh も実行したい場合のみ true
run_after_apply = false
```

### 2) init / apply
```bash
# 初期化
terraform init

# 事前確認
terraform plan

# 実行(yes の入力省略)
terraform apply -auto-approve
#　ネットワークを固定したしたいとき
terraform apply -auto-approve -var="my_ip_cidr=203.0.113.10/32"

# クリーンな状態に戻す(yes の入力省略)
terraform destroy -auto-approve
```

apply の最後に以下が順番に実行されます:

1. `scripts/update_env.sh`（必ず実行）

    - `./00_env.sh` を `./00_env.sh.bak_YYYYmmdd_HHMMSS` にバックアップ
    - 8変数だけを上書き更新（他の変数は保持）

2. `./99_run_all.sh`（`run_after_apply=true` のときだけ実行）

---
</br>
</br>

## 00_env.sh で更新される変数
**Public**
- WEB_PUBLIC_IP
- AP_PUBLIC_IP
- DB_PUBLIC_IP
- INNER_DNS_PUBLIC_IP

**Private**
- WEB_PRIVATE_IP
- AP_PRIVATE_IP
- DB_PRIVATE_IP
- INNER_DNS_PRIVATE_IP

その他の変数（SSH_USER / SSH_KEY_PATH / WP_DB_NAME 等）は保持されます。

---
</br>
</br>


## セキュリティグループ仕様（要件どおり）
**共通（全SG）:**

- inbound: SSH 22/tcp を `my_ip_cidr` のみ許可

- outbound: all allow

**WEB SG:**

- inbound: HTTP 80/tcp を `my_ip_cidr` のみ許可（0.0.0.0/0は禁止）

**AP SG:**

- inbound: TCP 9000 を WEB SG からのみ許可（CIDRでなく SG参照）

**DB SG:**

- inbound: MySQL 3306/tcp を AP SG からのみ許可（SG参照）

**INNER_DNS SG:**

- inbound: DNS 53/udp を 0.0.0.0/0 から許可

- inbound: DNS 53/tcp を `my_network_cidr` のみ許可

---
</br>
</br>


## outputs
```bash
terraform output
terraform output -json
```
各EC2の Public/Private IP を出力します。

---
</br>
</br>


## 注意点（mac / linux差分など）
- `scripts/update_env.sh` は `python3` を使って `terraform output -json` を解析します。

    - macOS / Linux ともに python3 が入っていれば動きます（Homebrew等で導入可）

- `00_env.sh` の該当8変数が存在しない場合は末尾に追記します。

- `subnet_id` は指定していません（既定VPC/既定サブネットの挙動に任せます）。

    - もし「既定サブネットで public IP が付かない」環境の場合、
    AWS 側の Default Subnet の Auto-assign public IPv4 設定を確認してください。

---
</br>
</br>


## 補足（設計意図：冪等性 / 実行順）
- `null_resource.update_env` は **4台のIPが変わったときだけ** 再実行されます（`triggers` にIPを持たせているため）。
- `null_resource.run_all` は `run_after_apply=true` のときだけ作成され、**必ず update_env の後に** 実行されます（`depends_on`）。

---
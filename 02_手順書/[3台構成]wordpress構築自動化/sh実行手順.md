# 目的
### EC2を3台構成で構築し、各EC2間で通信をして、wordpressが動作するようにする。
</br>
</br>



# 構成
```bash
[ EC2① ] Web + WordPress
   |
   | WEB→AP:9000
   v
[ EC2② ] php-fpm + WordPress
   |
   | AP→DB:3306
   v
[ EC2③ ] MariaDB（DB専用）
```
</br>
</br>



# 手順
## 【前提】
- 転送元のshファイルがダウンロードフォルダに格納してあること。
- EC2が3台が作成してあること。
- セキュリティグループの設定がされていること。
---
</br>
</br>



## 【sh実行準備】
**1. sh格納ディレクトリに移動**
```bash
cd wp-3tier
```


**2. 権限付与**
```bash
chmod +x ./*.sh
```


**3. 00_env.sh のIP等を自分の環境に合わせる**
```bash
# ===== SSH接続情報（ローカルから親shが使う）=====
SSH_USER="ec2-user"
SSH_KEY_PATH="${HOME}/.ssh/PS_kurosawa_key.pem"

WEB_PUBLIC_IP="16.146.84.97"
AP_PUBLIC_IP="44.243.38.61"
DB_PUBLIC_IP="35.93.39.192"

# ===== サーバ間通信（プライベートIP）=====
WEB_PRIVATE_IP="172.31.23.104"
AP_PRIVATE_IP="172.31.18.19"
DB_PRIVATE_IP="172.31.26.139"

# ===== WordPress / DB設定 =====
WP_DB_NAME="wordpress-db"
WP_DB_USER="kurosawa"
WP_DB_PASS="kurosawa"
```


**4. 実行**
```bash
./99_run_all.sh
```
---
</br>
</br>


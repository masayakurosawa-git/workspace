#!/bin/bash
set -euo pipefail

#######################################
# ログ設定
#######################################
# ログファイル
SCRIPT_NAME="$(basename "$0" .sh)"
LOG_FILE="$(pwd)/${SCRIPT_NAME}_$(date '+%Y%m%d_%H%M%S').log"

# 1回だけ script で自分自身を包んで実行（tty出力も含めて全部ログ化）
if [[ -z "${__LOGGED_WITH_SCRIPT:-}" ]]; then
  export __LOGGED_WITH_SCRIPT=1

  # -q: 開始/終了メッセージ抑制, -f: フラッシュ（リアルタイム）, -a: 追記
  # bash -lc: login shell風に実行（環境差分が出にくい）
  exec script -q -f -a "$LOG_FILE" -c "bash -lc '\"$0\" \"$@\"'"
fi

echo "======================================"
echo " WordPress(WEB) セットアップ開始"
echo " 開始時刻: $(date)"
echo " ログファイル: $LOG_FILE"
echo "======================================"

#######################################
# 対話形式で変数を取得
#######################################
echo "=== セットアップ用の値を入力してください（Enterでデフォルト採用） ==="

read -p "Web Server のパブリック IP（例: 35.xxx.xxx.xxx）: " WEB_PUBLIC_IP
while [[ -z "${WEB_PUBLIC_IP}" ]]; do
  read -p "Web Server のパブリック IP（空は不可）: " WEB_PUBLIC_IP
  echo
done

read -p "DB Server のプライベート IP（例: 35.xxx.xxx.xxx）: " DB_PRIVATE_IP
while [[ -z "${DB_PRIVATE_IP}" ]]; do
  read -p "DB Server のプライベート IP（空は不可）: " DB_PRIVATE_IP
  echo
done

read -p "WordPress DB 名 : " WP_DB_NAME
WP_DB_NAME=${WP_DB_NAME}
while [[ -z "${WP_DB_NAME}" ]]; do
  read -s -p "WordPress DB 名（空は不可）: " WP_DB_NAME
  echo
done

read -p "WordPress DB ユーザー名 : " WP_DB_USER
WP_DB_USER=${WP_DB_USER}
while [[ -z "${WP_DB_USER}" ]]; do
  read -s -p "WordPress DB ユーザ名（空は不可）: " WP_DB_USER
  echo
done

read -s -p "WordPress DB パスワード（空は不可）: " WP_DB_PASS
echo
while [[ -z "${WP_DB_PASS}" ]]; do
  read -s -p "WordPress DB パスワード（空は不可）: " WP_DB_PASS
  echo
done

read -s -p "MariaDB root パスワード（mysql_secure_installationで設定、空は不可）: " MYSQL_ROOT_PASS
echo
while [[ -z "${MYSQL_ROOT_PASS}" ]]; do
  read -s -p "MariaDB root パスワード（空は不可）: " MYSQL_ROOT_PASS
  echo
done

echo
echo "=============================="
echo "Web Server Public IP : ${WEB_PUBLIC_IP}"
echo "DB Server Private IP : ${DB_PRIVATE_IP}"
echo "WP DB Name    : ${WP_DB_NAME}"
echo "WP DB User    : ${WP_DB_USER}"
echo "WP DB Pass    : ********"
echo "DB root Pass  : ********"
echo "=============================="
read -p "この内容で続行しますか？ (y/N): " CONFIRM
[[ "${CONFIRM:-}" =~ ^[Yy]$ ]] || { echo "中止しました。"; exit 1; }

#######################################
# 固定値（必要ならここも編集可）
#######################################
# EC2 / OS ユーザー
OS_USER="ec2-user"
APACHE_GROUP="apache"

# WordPress パス
WEB_ROOT="/var/www/html"
WP_TMP_DIR="$HOME/wordpress"

#######################################
# Step 1: パッケージ更新 & LAMP構築
#######################################

echo "=== パッケージ更新 ==="
sudo dnf upgrade -y

echo "=== Apache / PHP インストール ==="
sudo dnf install -y \
  httpd wget \
  php php-fpm php-mysqli php-json php-devel \
  php-mysqlnd php-gd


#######################################
# Step 2: Apache 起動・自動起動
#######################################

echo "=== Apache 起動 ==="
sudo systemctl start httpd
sudo systemctl enable httpd


#######################################
# Step 3: /var/www 権限設定
#######################################

echo "=== Apache グループにユーザー追加 ==="
sudo usermod -a -G ${APACHE_GROUP} ${OS_USER}

echo "=== Apache グループ反映 ==="
newgrp "${APACHE_GROUP}" <<EOF
echo "apache グループを有効化しました"
EOF

echo "=== ドキュメントルート権限変更 ==="
sudo chown -R ${OS_USER}:${APACHE_GROUP} /var/www
sudo chmod 2775 /var/www
sudo find /var/www -type d -exec chmod 2775 {} \;
sudo find /var/www -type f -exec chmod 0664 {} \;


#######################################
# Step 4: PHP 動作確認（curl 自動チェック）
#######################################

echo "=== PHP 動作確認（curl） ==="

PHPINFO_FILE="${WEB_ROOT}/phpinfo.php"
CHECK_URL="http://127.0.0.1/phpinfo.php"

# phpinfo.php 作成
echo "<?php phpinfo(); ?>" | sudo tee ${PHPINFO_FILE} > /dev/null

# curl で HTTP ステータス取得
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" ${CHECK_URL})

echo "HTTP STATUS: ${HTTP_STATUS}"

if [ "${HTTP_STATUS}" = "200" ]; then
    echo "[OK] PHP 正常動作を確認（200 OK）"
    sudo rm -f ${PHPINFO_FILE}
else
    echo "[NG] PHP 動作確認失敗（status=${HTTP_STATUS}）"
    echo "   Apache / PHP-FPM の状態を確認してください"
    echo "   - sudo systemctl status httpd"
    echo "   - sudo systemctl status php-fpm"
    exit 1
fi


#######################################
# Step 6: WordPress セットアップ
#######################################

echo "=== WordPress ダウンロード ==="
cd $HOME
wget -q https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

echo "=== wp-config.php 設定 ==="
cp -a wordpress/wp-config-sample.php wordpress/wp-config.php

sed -i \
  -e "s/database_name_here/${WP_DB_NAME}/" \
  -e "s/username_here/${WP_DB_USER}/" \
  -e "s/password_here/${WP_DB_PASS}/" \
  -e "s/localhost/${DB_PRIVATE_IP}/" \
  wordpress/wp-config.php


echo "=== WordPress 配置 ==="
sudo cp -r wordpress/* ${WEB_ROOT}/


echo "=== httpd.conf 設定変更 ==="
sudo cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.`date +"%Y%m%d_%H%M%S"`.bak

sudo sed -i \
  's/AllowOverride None/AllowOverride All/' \
  /etc/httpd/conf/httpd.conf


echo "=== Apache 再起動 ==="
sudo systemctl restart httpd

#######################################
# 完了
#######################################

echo "======================================="
echo " WordPress(WEB) セットアップ完了！"
echo "ブラウザで以下にアクセスしてください"
echo "http://${WEB_PUBLIC_IP}/"
echo "（もし表示されない場合は、SGで80番が許可されているか確認）"
echo "（もし表示されない場合は、SGで3306番が許可されているか確認）"
echo "======================================="

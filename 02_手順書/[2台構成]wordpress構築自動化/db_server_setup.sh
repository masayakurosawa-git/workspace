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
echo " WordPress(DB) セットアップ開始"
echo " 開始時刻: $(date)"
echo " ログファイル: $LOG_FILE"
echo "======================================"

#######################################
# 対話形式で変数を取得
#######################################
echo "=== セットアップ用の値を入力してください（Enterでデフォルト採用） ==="

read -p "DB Server のプライベート IP（例: 35.xxx.xxx.xxx）: " DB_PRIVATE_IP
while [[ -z "${DB_PRIVATE_IP}" ]]; do
  read -p "DB Server のプライベート IP（空は不可）: " DB_PRIVATE_IP
  echo
done

read -p "Web Server のプライベート IP（例: 35.xxx.xxx.xxx）: " WEB_PRIVATE_IP
while [[ -z "${WEB_PRIVATE_IP}" ]]; do
  read -p "Web Server のプライベート IP（空は不可）: " WEB_PRIVATE_IP
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
echo "DB Server Private IP : ${DB_PRIVATE_IP}"
echo "Web Server Private IP : ${WEB_PRIVATE_IP}"
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
# Step 1: パッケージ更新 & MariaDB構築
#######################################

echo "=== パッケージ更新 ==="
sudo dnf upgrade -y

echo "=== MariaDB インストール ==="
sudo dnf install -y mariadb105-server


#######################################
# Step 2: MariaDB 起動・自動起動
#######################################

echo "=== MariaDB 起動 ==="
sudo systemctl start mariadb
sudo systemctl enable mariadb


#######################################
# Step 5: MariaDB セットアップ
#######################################

echo "=== mysql_secure_installation 自動実行 ==="

sudo dnf install -y expect

expect <<EOF
set timeout 20

spawn sudo mysql_secure_installation

expect "Enter current password for root*"
send "\r"

expect "Switch to unix_socket authentication*"
send "y\r"

expect "Change the root password*"
send "y\r"

expect "New password:"
send "${MYSQL_ROOT_PASS}\r"

expect "Re-enter new password:"
send "${MYSQL_ROOT_PASS}\r"

expect "Remove anonymous users*"
send "y\r"

expect "Disallow root login remotely*"
send "y\r"

expect "Remove test database and access to it*"
send "y\r"

expect "Reload privilege tables now*"
send "y\r"

expect eof
EOF


#######################################
# Step 6: WordPress用DB作成
#######################################

echo "=== WordPress DB & USER 作成 ==="
sudo mysql -u root -p"${MYSQL_ROOT_PASS}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${WP_DB_NAME}\`;
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'${WEB_PRIVATE_IP}' IDENTIFIED BY '${WP_DB_PASS}';
GRANT ALL PRIVILEGES ON \`${WP_DB_NAME}\`.* TO '${WP_DB_USER}'@'${WEB_PRIVATE_IP}';
FLUSH PRIVILEGES;
SQL

CONF_FILE="/etc/my.cnf.d/mariadb-server.cnf"
BACKUP_FILE="${CONF_FILE}.`date +'%Y%m%d_%H%M%S'`.bak"

echo "=== MariaDB 設定ファイルのバックアップ ==="
sudo cp -a "${CONF_FILE}" "${BACKUP_FILE}"
echo "Backup created: ${BACKUP_FILE}"


echo "=== [mysqld] ブロックに bind-address を設定 ==="

sudo awk -v ip="${WEB_PRIVATE_IP}" '
BEGIN {
  in_mysqld = 0
  bind_set = 0
}

/^\[mysqld\]/ {
  print
  in_mysqld = 1
  next
}

/^\[/ {
  if (in_mysqld && !bind_set) {
    print "bind-address=" ip
    bind_set = 1
  }
  in_mysqld = 0
  print
  next
}

in_mysqld && /^bind-address=/ {
  print "bind-address=" ip
  bind_set = 1
  next
}

{
  print
}

END {
  if (in_mysqld && !bind_set) {
    print "bind-address=" ip
  }
}
' "${CONF_FILE}" > /tmp/mariadb-server.cnf.tmp

sudo mv /tmp/mariadb-server.cnf.tmp "${CONF_FILE}"


echo "=== 設定反映内容確認 ==="
grep -nE '^\[mysqld\]|^bind-address=' "${CONF_FILE}"


echo "=== MariaDB 再起動 ==="
sudo systemctl restart mariadb


#######################################
# 完了
#######################################

echo "======================================="
echo " WordPress(DB) セットアップ完了！"
echo " 次に WordPress(WEB) のセットアップを実施してください。"
echo "======================================="

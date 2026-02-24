#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/01_common.sh"
source "${SCRIPT_DIR}/00_env.sh"

run_with_spinner "dnf upgrade" sudo dnf upgrade -y

# 手順にあるPHP関連パッケージ :contentReference[oaicite:8]{index=8}
run_with_spinner "Install PHP packages" sudo dnf install -y wget tar \
  php-fpm php-mysqli php-json php php-devel php-mysqlnd php-gd

# php-fpm 設定（listen=9000 / allowed_clients=WEB_PRIVATE_IP） :contentReference[oaicite:9]{index=9}
run_with_spinner "Configure php-fpm www.conf" sudo bash -c "
cp -a /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.$(date +%Y%m%d_%H%M%S).bak

sed -i \
  -e 's/^user = .*/user = apache/' \
  -e 's/^group = .*/group = apache/' \
  -e 's/^listen = .*/listen = 9000/' \
  -e 's/^;\\?listen.allowed_clients = .*/listen.allowed_clients = ${WEB_PRIVATE_IP}/' \
  /etc/php-fpm.d/www.conf
"

run_with_spinner "php-fpm enable/start" sudo systemctl enable --now php-fpm

# （手順に合わせて）SELinux boolean :contentReference[oaicite:10]{index=10}
run_with_spinner "SELinux httpd_can_network_connect on" sudo setsebool -P httpd_can_network_connect on

# WordPress 配置（WEBと同じパスに置くのが重要：Proxy先でSCRIPT_FILENAMEが一致する前提）
run_with_spinner "Download WordPress" bash -c "cd /tmp && curl -fsSL -o latest.tar.gz https://wordpress.org/latest.tar.gz"
run_with_spinner "Extract WordPress" bash -c "cd /tmp && tar -xzf latest.tar.gz"

run_with_spinner "Prepare wp-config.php" bash -c "cp -a /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
sed -i \
  -e \"s/define( 'DB_NAME', .*/define( 'DB_NAME', '${WP_DB_NAME}' );/\" \
  -e \"s/define( 'DB_USER', .*/define( 'DB_USER', '${WP_DB_USER}' );/\" \
  -e \"s/define( 'DB_PASSWORD', .*/define( 'DB_PASSWORD', '${WP_DB_PASS}' );/\" \
  -e \"s/define( 'DB_HOST', .*/define( 'DB_HOST', '${SUB_DOMAIN_DB}' );/\" \
  /tmp/wordpress/wp-config.php"

run_with_spinner "Deploy WordPress to /var/www/html" sudo bash -c "mkdir -p /var/www/html
rm -rf /var/www/html/*
cp -a /tmp/wordpress/* /var/www/html/"

run_with_spinner "Set permissions for /var/www/html" sudo bash -c "chown -R apache:apache /var/www/html && chmod -R 755 /var/www/html"

# PHP動作確認ファイル :contentReference[oaicite:5]{index=5}
run_with_spinner "Create /var/www/html/info.php" sudo bash -c "echo '<?php phpinfo(); ?>' > /var/www/html/info.php"
run_with_spinner "Chown info.php" sudo chown apache:apache /var/www/html/info.php

# DNS向き先設定
set_dns_resolver "${INNER_DNS_PRIVATE_IP}" "${DOMAIN_NAME_INNER}"

echo "AP setup done. LOG=${LOG_FILE}"

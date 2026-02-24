#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=01_common.sh
source "${SCRIPT_DIR}/01_common.sh"
# shellcheck source=00_env.sh
source "${SCRIPT_DIR}/00_env.sh"

run_with_spinner "dnf upgrade" sudo dnf upgrade -y
run_with_spinner "Apache install" sudo dnf install -y httpd

run_with_spinner "Apache enable/start" sudo systemctl enable --now httpd

# PHP を AP に転送する設定（/etc/httpd/conf.d/php-fpm.conf）
# 手順の FilesMatch/SetHandler を自動生成 :contentReference[oaicite:4]{index=4}
run_with_spinner "Apache php-fpm proxy config" sudo bash -c "cat > /etc/httpd/conf.d/php-fpm.conf <<'EOF'
<FilesMatch \\.php$>
    SetHandler \"proxy:fcgi://${SUB_DOMAIN_AP}:9000\"
</FilesMatch>
EOF"

run_with_spinner "SELinux httpd_can_network_connect on" sudo setsebool -P httpd_can_network_connect on
run_with_spinner "Apache restart" sudo systemctl restart httpd

# WordPress インストール（WEB/AP 共通手順） :contentReference[oaicite:6]{index=6}
run_with_spinner "Download WordPress" bash -c "cd /tmp && curl -fsSL -o latest.tar.gz https://wordpress.org/latest.tar.gz"
run_with_spinner "Extract WordPress" bash -c "cd /tmp && tar -xzf latest.tar.gz"

run_with_spinner "Prepare wp-config.php" bash -c "cp -a /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
sed -i \
  -e \"s/define( 'DB_NAME', .*/define( 'DB_NAME', '${WP_DB_NAME}' );/\" \
  -e \"s/define( 'DB_USER', .*/define( 'DB_USER', '${WP_DB_USER}' );/\" \
  -e \"s/define( 'DB_PASSWORD', .*/define( 'DB_PASSWORD', '${WP_DB_PASS}' );/\" \
  -e \"s/define( 'DB_HOST', .*/define( 'DB_HOST', '${SUB_DOMAIN_DB}' );/\" \
  /tmp/wordpress/wp-config.php"

run_with_spinner "Deploy WordPress to /var/www/html" sudo bash -c "rm -rf /var/www/html/*
cp -a /tmp/wordpress/* /var/www/html/"

run_with_spinner "Set permissions for /var/www/html" sudo bash -c "chown -R apache:apache /var/www/html && chmod -R 755 /var/www/html"

# PHP動作確認ファイル :contentReference[oaicite:5]{index=5}
run_with_spinner "Create /var/www/html/info.php" sudo bash -c "echo '<?php phpinfo(); ?>' > /var/www/html/info.php"
run_with_spinner "Chown info.php" sudo chown apache:apache /var/www/html/info.php

# DirectoryIndex 変更（WEBのみ） :contentReference[oaicite:7]{index=7}
run_with_spinner "Backup httpd.conf" sudo cp -a /etc/httpd/conf/httpd.conf "/etc/httpd/conf/httpd.conf.$(date +%Y%m%d_%H%M%S).bak"
run_with_spinner "Set DirectoryIndex index.php first" sudo bash -c "grep -q '^DirectoryIndex' /etc/httpd/conf/httpd.conf \
  && sed -i 's/^DirectoryIndex.*/DirectoryIndex index.php index.html/' /etc/httpd/conf/httpd.conf \
  || echo 'DirectoryIndex index.php index.html' >> /etc/httpd/conf/httpd.conf"

run_with_spinner "Apache restart (apply DirectoryIndex)" sudo systemctl restart httpd

# DNS向き先設定
set_dns_resolver "${INNER_DNS_PRIVATE_IP}" "${DOMAIN_NAME_INNER}"

echo "WEB setup done. LOG=${LOG_FILE}"

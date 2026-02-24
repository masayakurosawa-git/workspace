#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SQL_FILE="${SCRIPT_DIR}/wp_init.sql"
source "${SCRIPT_DIR}/01_common.sh"
source "${SCRIPT_DIR}/00_env.sh"

run_with_spinner "dnf upgrade" sudo dnf upgrade -y
run_with_spinner "Install MariaDB" sudo dnf install -y mariadb105-server
run_with_spinner "MariaDB enable/start" sudo systemctl enable --now mariadb

# 手順では mysql_secure_installation を対話実行 :contentReference[oaicite:11]{index=11}
# ここでは「WP用DB/ユーザ作成」を非対話で実施（実運用の堅牢化は別途推奨）
run_with_spinner "Create WP DB & User" sudo bash -c "
cat > ${SQL_FILE} <<SQL
CREATE DATABASE IF NOT EXISTS ${WP_DB_NAME};
CREATE USER IF NOT EXISTS '${WP_DB_USER}'@'${AP_PRIVATE_IP}' IDENTIFIED BY '${WP_DB_PASS}';
GRANT ALL PRIVILEGES ON ${WP_DB_NAME}.* TO '${WP_DB_USER}'@'${AP_PRIVATE_IP}';
FLUSH PRIVILEGES;
SQL

sudo mariadb < ${SQL_FILE}
rm -f ${SQL_FILE}
"

# DNS向き先設定
set_dns_resolver "${INNER_DNS_PRIVATE_IP}" "${DOMAIN_NAME_INNER}"

echo "DB setup done. LOG=${LOG_FILE}"

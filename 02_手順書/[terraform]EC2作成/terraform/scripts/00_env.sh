#!/usr/bin/env bash
set -euo pipefail

# ===== SSH接続情報（ローカルから親shが使う）=====
SSH_USER="ec2-user"
SSH_KEY_PATH="${HOME}/.ssh/CL_kurosawa_key.pem"

WEB_PUBLIC_IP="13.114.109.237"
AP_PUBLIC_IP="54.250.188.12"
DB_PUBLIC_IP="52.195.208.222"
INNER_DNS_PUBLIC_IP="57.181.27.85"
#OUTER_DNS_PUBLIC_IP=""

# ===== サーバ間通信（プライベートIP）=====
WEB_PRIVATE_IP="172.31.45.113"
AP_PRIVATE_IP="172.31.47.109"
DB_PRIVATE_IP="172.31.40.42"
INNER_DNS_PRIVATE_IP="172.31.43.170"
#OUTER_DNS_PRIVATE_IP=""
LOCAL_HOST="127.0.0.1"

# ===== WordPress / DB設定 =====
WP_DB_NAME="wordpress_db" #「-」は使用しないこと
WP_DB_USER="kurosawa"
WP_DB_PASS="kurosawa"

# ===== ドメイン設定 =====
#DOMAIN_NAME_OUTER="wp.example.com"
DOMAIN_NAME_INNER="wp.local"
SUB_DOMAIN_AP="ap.${DOMAIN_NAME_INNER}"
SUB_DOMAIN_DB="db.${DOMAIN_NAME_INNER}"
SUB_DOMAIN_WEB="web.${DOMAIN_NAME_INNER}"

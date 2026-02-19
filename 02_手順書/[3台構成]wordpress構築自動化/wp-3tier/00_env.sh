#!/usr/bin/env bash
set -euo pipefail

# ===== SSH接続情報（ローカルから親shが使う）=====
SSH_USER="ec2-user"
SSH_KEY_PATH="${HOME}/.ssh/CL_kurosawa_key.pem"

WEB_PUBLIC_IP="18.237.80.150"
AP_PUBLIC_IP="52.43.125.127"
DB_PUBLIC_IP="52.11.62.134"
INNER_DNS_PUBLIC_IP="35.85.64.133"
#OUTER_DNS_PUBLIC_IP=""

# ===== サーバ間通信（プライベートIP）=====
WEB_PRIVATE_IP="172.31.23.104"
AP_PRIVATE_IP="172.31.18.19"
DB_PRIVATE_IP="172.31.26.139"
INNER_DNS_PRIVATE_IP="172.31.31.220"
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

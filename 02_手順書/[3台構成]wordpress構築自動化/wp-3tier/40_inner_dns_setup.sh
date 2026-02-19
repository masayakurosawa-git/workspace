#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/01_common.sh"
source "${SCRIPT_DIR}/00_env.sh"

run_with_spinner "dnf upgrade" sudo dnf upgrade -y
run_with_spinner "Install bind" sudo dnf install -y bind bind-utils

run_with_spinner "named enable/start" sudo systemctl enable --now named

# zone ファイル作成
run_with_spinner "Create zone file" sudo bash -c "
cat > /var/named/${DOMAIN_NAME_INNER}.zone <<'EOF'
\$TTL 86400
@   IN  SOA ns.${DOMAIN_NAME_INNER}. root.${DOMAIN_NAME_INNER}. (
        2026021801 ; Serial
        3600       ; Refresh
        1800       ; Retry
        604800     ; Expire
        86400 )    ; Minimum

@   IN  NS  ns.${DOMAIN_NAME_INNER}.
ns  IN  A   ${INNER_DNS_PRIVATE_IP}
ap  IN  A   ${AP_PRIVATE_IP}
web IN  A   ${WEB_PRIVATE_IP}
db  IN  A   ${DB_PRIVATE_IP}
EOF
"

# named.conf の修正
run_with_spinner "named.conf allow-query/listen-on update" sudo bash -c '
set -e

CONF="/etc/named.conf"
TS=$(date +%Y%m%d_%H%M%S)

# バックアップ
cp -a "${CONF}" "${CONF}.${TS}.bak"

# listen-on / listen-on-v6 をコメントアウト（既にコメントならそのまま）
# 例: listen-on port 53 { 127.0.0.1; }; → #listen-on port 53 { 127.0.0.1; };
sed -i -E \
  -e "s/^([[:space:]]*)listen-on([[:space:]]+port[[:space:]]+53[[:space:]]+\\{[[:space:]]*127\\.0\\.0\\.1;[[:space:]]*\\};)/\\1#listen-on\\2/" \
  -e "s/^([[:space:]]*)listen-on-v6([[:space:]]+port[[:space:]]+53[[:space:]]+\\{[[:space:]]*::1;[[:space:]]*\\};)/\\1#listen-on-v6\\2/" \
  "${CONF}"

# allow-query を any に（行があれば置換。なければ options ブロックに追加）
if grep -qE "^[[:space:]]*allow-query[[:space:]]*\\{" "${CONF}"; then
  sed -i -E "s|^[[:space:]]*allow-query[[:space:]]*\\{[^}]*\\};|allow-query     { any; };|g" "${CONF}"
else
  # options { の直後に入れる（見つからない場合は末尾に追加）
  if grep -qE "^[[:space:]]*options[[:space:]]*\\{" "${CONF}"; then
    sed -i -E "/^[[:space:]]*options[[:space:]]*\\{/a\\
    allow-query     { any; };
" "${CONF}"
  else
    echo "allow-query     { any; };" >> "${CONF}"
  fi
fi

echo "==> Backup: ${CONF}.${TS}.bak"
'

# ドメイン定義追加
run_with_spinner "named.conf update" sudo bash -c "
grep -q '${DOMAIN_NAME_INNER}' /etc/named.conf || cat >> /etc/named.conf <<CONF

zone \"${DOMAIN_NAME_INNER}\" IN {
    type master;
    file \"${DOMAIN_NAME_INNER}.zone\";
};
CONF
"

run_with_spinner "named-checkconf" sudo named-checkconf /etc/named.conf
run_with_spinner "named restart" sudo systemctl restart named
run_with_spinner "named status" sudo systemctl status named --no-pager -l

# DNS向き先設定
set_dns_resolver "${LOCAL_HOST}" "${DOMAIN_NAME_INNER}"

echo "DNS setup done"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00_env.sh"

# ローカル側にも簡易スピナー（ssh/scp待ちが長いので）
run_with_spinner() {
  local title="$1"; shift
  local spin='|/-\'
  local i=0
  echo "==> ${title}"
  ( "$@" ) >/tmp/wp3tier_parent.log 2>&1 &
  local pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 ))
    printf "\r[%c] %s" "${spin:$i:1}" "$title"
    sleep 0.12
  done
  wait "$pid"
  local rc=$?
  if [ "$rc" -eq 0 ]; then
    printf "\r[✓] %s\n" "$title"
  else
    printf "\r[✗] %s (rc=%s)\n" "$title" "$rc"
    echo "    親ログ: /tmp/wp3tier_parent.log"
    return "$rc"
  fi
}

remote_run() {
  local host="$1"
  local remote_script="$2"
  local title="$3"
  local rdir="/home/${SSH_USER}/wp-3tier"

  # 配布先ディレクトリ作成
  run_with_spinner "${title}: create dir on ${host}" \
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
      "${SSH_USER}@${host}" "mkdir -p ${rdir}"

  # ファイル転送
  run_with_spinner "${title}: upload scripts to ${host}" \
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
      "${SCRIPT_DIR}/00_env.sh" \
      "${SCRIPT_DIR}/01_common.sh" \
      "${SCRIPT_DIR}/${remote_script}" \
      "${SSH_USER}@${host}:${rdir}/"

  # 権限付与
  run_with_spinner "${title}: chmod +x on ${host}" \
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
      "${SSH_USER}@${host}" "chmod +x ${rdir}/*.sh"

  # スクリプト実行
  run_with_spinner "${title}: execute on ${host}" \
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no \
      "${SSH_USER}@${host}" "bash ${rdir}/${remote_script}"
}

# 設定確認
echo
echo "===== SSH接続情報 ====="
echo "WEB Public IP : ${WEB_PUBLIC_IP}"
echo "AP Public IP : ${AP_PUBLIC_IP}"
echo "DB Public IP : ${DB_PUBLIC_IP}"
echo "内部DNS Public IP : ${INNER_DNS_PUBLIC_IP}"
echo "===== WordPress / DB設定 ====="
echo "WP DB Name    : ${WP_DB_NAME}"
echo "WP DB User    : ${WP_DB_USER}"
echo "WP DB Pass    : ********"
echo "===== ドメイン設定 ====="
echo "WP DB Name    : ${DOMAIN_NAME_INNER}"
echo "WP DB Name    : ${SUB_DOMAIN_WEB}"
echo "WP DB Name    : ${SUB_DOMAIN_AP}"
echo "WP DB Name    : ${SUB_DOMAIN_DB}"
echo "=============================="
read -p "この内容で続行しますか？ (y/N): " CONFIRM
[[ "${CONFIRM:-}" =~ ^[Yy]$ ]] || { echo "中止しました。"; exit 1; }
echo

# 実行順（DB → AP → WEB → 内部DNS）
remote_run "$DB_PUBLIC_IP"  "30_db_setup.sh" "DB setup"
remote_run "$AP_PUBLIC_IP"  "20_ap_setup.sh" "AP setup"
remote_run "$WEB_PUBLIC_IP" "10_web_setup.sh" "WEB setup"
remote_run "$INNER_DNS_PUBLIC_IP" "40_inner_dns_setup.sh" "INNER DNS setup"
#remote_run "$OUTER_DNS_PUBLIC_IP" "50_inner_dns_setup.sh" "OUTER DNS setup"

echo
echo "======================================="
echo " WordPress セットアップ完了！"
echo " ↓ ブラウザで以下にアクセスしてください"
echo "http://${WEB_PUBLIC_IP}/"
echo " ↓ PHP動作確認用はこちら"
echo "http://${WEB_PUBLIC_IP}/info.php"
echo "（もし表示されない場合は、SGで80番が許可されているか確認）"
echo "======================================="
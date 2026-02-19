#!/usr/bin/env bash
set -euo pipefail

# ホーム配下に logs ディレクトリを作る
LOG_DIR="${LOG_DIR:-$HOME/wp-logs}"
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"

# ログは各サーバ側で保存
LOG_FILE="${LOG_FILE:-$LOG_DIR/wp_setup_$(date +%Y%m%d_%H%M%S).log}"
: > "$LOG_FILE"          # 作成/上書き（ec2-user権限で）
chmod 600 "$LOG_FILE"

run_with_spinner() {
  local title="$1"; shift
  local spin='|/-\'
  local i=0

  echo "==> ${title}"

  ( "$@" ) >>"$LOG_FILE" 2>&1 &
  local pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    i=$(( (i + 1) % 4 ))
    printf "\r[%c] %s" "${spin:$i:1}" "$title"
    sleep 0.12
  done

  local rc=0
  wait "$pid" || rc=$?

  if [ "$rc" -eq 0 ]; then
    printf "\r[✓] %s\n" "$title"
  else
    printf "\r[✗] %s (rc=%s)\n" "$title" "$rc"
    echo "    ログ: $LOG_FILE"
    return "$rc"
  fi
}


# DNS向き先設定
set_dns_resolver() {
  local dns1="$1"
  local domain="$2"

  echo "==> Configure systemd-resolved DNS ${dns1}"

  # バックアップ
  sudo cp -a /etc/systemd/resolved.conf \
      /etc/systemd/resolved.conf.$(date +%Y%m%d_%H%M%S).bak

  # DNS= を置換（コメント含む）
  sudo sed -i \
    -e "s|^#\?DNS=.*|DNS=${dns1}|" \
    -e "s|^#\?FallbackDNS=.*|FallbackDNS=|" \
    -e "s|^#\?Domains=.*|Domains=${domain}|" \
    /etc/systemd/resolved.conf

  # 再起動
  sudo systemctl restart systemd-resolved

  echo "==> systemd-resolved restarted"
}


#!/usr/bin/env bash
set -euo pipefail

INV_FILE="${1:-./ansible/inventory/hosts.ini}"
TIMEOUT_SEC="${TIMEOUT_SEC:-300}"
SLEEP_SEC="${SLEEP_SEC:-5}"

# inventory からIPだけ抽出（セクション/vars/空行を除外）
IPS=$(awk '
  /^\[/ {next}
  /^ansible_/ {next}
  /^[[:space:]]*$/ {next}
  {print $1}
' "$INV_FILE" | sort -u)

if [[ -z "${IPS}" ]]; then
  echo "[ERROR] No hosts found in inventory: ${INV_FILE}" >&2
  exit 1
fi

echo "[INFO] Waiting for SSH(22) to become available..."
echo "[INFO] Targets:"
echo "${IPS}" | sed 's/^/  - /'

for ip in ${IPS}; do
  echo "[INFO] wait: ${ip}:22 (timeout ${TIMEOUT_SEC}s)"
  start=$(date +%s)

  while true; do
    # macのnc想定（-z:port scan, -w:timeout）
    if nc -z -w 2 "${ip}" 22 >/dev/null 2>&1; then
      echo "[INFO] OK: ${ip}:22 is open"
      break
    fi

    now=$(date +%s)
    if (( now - start >= TIMEOUT_SEC )); then
      echo "[ERROR] Timeout waiting for ${ip}:22" >&2
      exit 1
    fi

    sleep "${SLEEP_SEC}"
  done
done
#!/usr/bin/env bash
set -euo pipefail

# このスクリプトの場所（terraform/scripts）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Ansibleディレクトリ（terraform の1つ上に ansible/ がある想定）
ANSIBLE_DIR="${ANSIBLE_DIR:-${TF_DIR}/ansible}"
HOSTS_FILE="${HOSTS_FILE:-${ANSIBLE_DIR}/inventory/hosts.ini}"

# all.yml の置き場所は環境差が出やすいので、よくある候補を自動判定
if [[ -n "${ALL_YML_FILE:-}" ]]; then
  ALL_FILE="${ALL_YML_FILE}"
else
  if [[ -f "${ANSIBLE_DIR}/group_vars/all.yml" ]]; then
    ALL_FILE="${ANSIBLE_DIR}/group_vars/all.yml"
  else
    echo "[ERROR] all.yml not found. Set ALL_YML_FILE env var to its path."
    exit 1
  fi
fi

if [[ ! -f "${HOSTS_FILE}" ]]; then
  echo "[ERROR] hosts.ini not found: ${HOSTS_FILE}"
  exit 1
fi
if [[ ! -f "${ALL_FILE}" ]]; then
  echo "[ERROR] all.yml not found: ${ALL_FILE}"
  exit 1
fi

############################################################
# Terraform outputs 取得処理
#
# 【背景】
# terraform apply 実行中の local-exec では、
# state に outputs がまだ書き込まれていない場合がある。
# その状態で `terraform output -json` を実行すると、
# 必要なキー（例: db_public_ip）が取得できずエラーになる。
#
# 【対策】
# Terraform 側（null_resource）から environment で
# IPアドレスを直接渡し、環境変数を優先利用する。
#
# 環境変数が存在しない場合のみ terraform output を実行する。
#
# ※この設計は apply途中の不安定な state 依存を避けるため。
############################################################
if [[ -n "${DB_PUBLIC_IP:-}" ]]; then
  TF_OUTPUT_JSON="$(python3 - <<'PY'
import json, os
keys = [
 "web_public_ip","ap_public_ip","db_public_ip","inner_dns_public_ip",
 "web_private_ip","ap_private_ip","db_private_ip","inner_dns_private_ip"
]
envmap = {
 "web_public_ip":"WEB_PUBLIC_IP",
 "ap_public_ip":"AP_PUBLIC_IP",
 "db_public_ip":"DB_PUBLIC_IP",
 "inner_dns_public_ip":"INNER_DNS_PUBLIC_IP",
 "web_private_ip":"WEB_PRIVATE_IP",
 "ap_private_ip":"AP_PRIVATE_IP",
 "db_private_ip":"DB_PRIVATE_IP",
 "inner_dns_private_ip":"INNER_DNS_PRIVATE_IP",
}
out={}
for k in keys:
  out[k]={"value": os.environ.get(envmap[k])}
print(json.dumps(out))
PY
)"
else
  TF_OUTPUT_JSON="$(cd "${TF_DIR}" && terraform output -json 2>/dev/null || true)"
fi

TS="$(date '+%Y%m%d_%H%M%S')"

# バックアップ
cp -a "${HOSTS_FILE}" "${HOSTS_FILE}.bak_${TS}"
cp -a "${ALL_FILE}"   "${ALL_FILE}.bak_${TS}"
echo "[INFO] Backup created:"
echo "  - ${HOSTS_FILE}.bak_${TS}"
echo "  - ${ALL_FILE}.bak_${TS}"

export TF_OUTPUT_JSON HOSTS_FILE ALL_FILE

python3 - <<'PY'
import json, os, re, sys

data = json.loads(os.environ["TF_OUTPUT_JSON"])
hosts_path = os.environ["HOSTS_FILE"]
all_path   = os.environ["ALL_FILE"]

def get(key: str) -> str:
    if key not in data or "value" not in data[key]:
        print(f"[ERROR] terraform output key not found: {key}", file=sys.stderr)
        sys.exit(1)
    v = data[key]["value"]
    return "" if v is None else str(v)

# outputs.tf 側はこの名前で出している前提
pub = {
  "web":       get("web_public_ip"),
  "ap":        get("ap_public_ip"),
  "db":        get("db_public_ip"),
  "inner_dns": get("inner_dns_public_ip"),
}
pri = {
  "web":       get("web_private_ip"),
  "ap":        get("ap_private_ip"),
  "db":        get("db_private_ip"),
  "inner_dns": get("inner_dns_private_ip"),
}

# ----- hosts.ini 更新（各グループの最初のIP行を置換）-----
with open(hosts_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

group = None
re_group = re.compile(r'^\s*\[(.+?)\]\s*$')
re_ipline = re.compile(r'^\s*([0-9]{1,3}\.){3}[0-9]{1,3}\s*$')

out = []
replaced = {k: False for k in pub.keys()}

for line in lines:
    m = re_group.match(line.strip())
    if m:
        group = m.group(1)
        out.append(line)
        continue

    # 対象グループ内で、最初のIP行だけ差し替え
    if group in pub and (not replaced[group]) and re_ipline.match(line.strip()):
        out.append(pub[group] + "\n")
        replaced[group] = True
    else:
        out.append(line)

with open(hosts_path, "w", encoding="utf-8") as f:
    f.writelines(out)

# ----- all.yml 更新（特定キーの値だけ差し替え）-----
with open(all_path, "r", encoding="utf-8") as f:
    yml = f.read()

def replace_kv(text: str, key: str, value: str) -> str:
    # key: "xxx" / key: xxx の両方に対応（行頭アンカー）
    pat = re.compile(rf'^(?P<k>{re.escape(key)}\s*:\s*)(?P<v>.*)$', re.MULTILINE)
    if not pat.search(text):
        # 無ければ末尾追記（運用上は存在している想定だが念のため）
        return text + f'\n{key}: "{value}"\n'
    return pat.sub(lambda m: m.group("k") + f'"{value}"', text, count=1)

mapping = {
  "web_public_ip": pub["web"],
  "ap_public_ip": pub["ap"],
  "db_public_ip": pub["db"],
  "inner_dns_public_ip": pub["inner_dns"],
  "web_private_ip": pri["web"],
  "ap_private_ip": pri["ap"],
  "db_private_ip": pri["db"],
  "inner_dns_private_ip": pri["inner_dns"],
}

for k, v in mapping.items():
    yml = replace_kv(yml, k, v)

with open(all_path, "w", encoding="utf-8") as f:
    f.write(yml)

print("[INFO] Updated:")
print(f"  - hosts.ini: {hosts_path}")
print(f"  - all.yml   : {all_path}")
print("[INFO] IPs injected:")
for role in ["web","ap","db","inner_dns"]:
    print(f"  - {role}: public={pub[role]} private={pri[role]}")
PY
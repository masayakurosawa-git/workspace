#!/usr/bin/env bash
set -euo pipefail

# ディレクトリ指定
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/00_env.sh"
TF_OUTPUT_JSON="$(terraform output -json 2>/dev/null || true)"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[ERROR] ${ENV_FILE} not found. Terraform directory must contain ./scripts/00_env.sh"
  exit 1
fi

if [[ -z "${TF_OUTPUT_JSON}" || "${TF_OUTPUT_JSON}" == "null" ]]; then
  echo "[ERROR] terraform output -json is empty/null."
  exit 1
fi

export ENV_FILE
export TF_OUTPUT_JSON


# バックアップ作成
TS="$(date '+%Y%m%d_%H%M%S')"
BACKUP="${ENV_FILE}.bak_${TS}"
cp -a "${ENV_FILE}" "${BACKUP}"
echo "[INFO] Backup created: ${BACKUP}"

# python3 で terraform output(json) をパースして 8変数だけ更新
python3 - <<'PY'
import json, os, re, sys, datetime

env_path = os.environ.get("ENV_FILE")

tf_json = os.environ.get("TF_OUTPUT_JSON")
if not tf_json:
    print("[ERROR] TF_OUTPUT_JSON is empty.", file=sys.stderr)
    sys.exit(1)

data = json.loads(tf_json)

def get_output(key: str) -> str:
    if key not in data or "value" not in data[key]:
        print(f"[ERROR] terraform output key not found: {key}", file=sys.stderr)
        sys.exit(1)
    v = data[key]["value"]
    if v is None:
        return ""
    return str(v)

updates = {
    "WEB_PUBLIC_IP":       get_output("web_public_ip"),
    "AP_PUBLIC_IP":        get_output("ap_public_ip"),
    "DB_PUBLIC_IP":        get_output("db_public_ip"),
    "INNER_DNS_PUBLIC_IP": get_output("inner_dns_public_ip"),
    "WEB_PRIVATE_IP":      get_output("web_private_ip"),
    "AP_PRIVATE_IP":       get_output("ap_private_ip"),
    "DB_PRIVATE_IP":       get_output("db_private_ip"),
    "INNER_DNS_PRIVATE_IP":get_output("inner_dns_private_ip"),
}

with open(env_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

# 既存行を置換（見つからない場合は末尾に追加）
found = {k: False for k in updates.keys()}

# 例: export WEB_PUBLIC_IP=... も許容し、先頭の export は残す
pat = re.compile(r'^(?P<prefix>\s*(?:export\s+)?)'
                 r'(?P<key>[A-Z0-9_]+)'
                 r'\s*=\s*(?P<val>.*)$')

new_lines = []
for line in lines:
    m = pat.match(line.rstrip("\n"))
    if not m:
        new_lines.append(line)
        continue

    key = m.group("key")
    if key not in updates:
        new_lines.append(line)
        continue

    prefix = m.group("prefix") or ""
    # 値は常にダブルクォートで上書き（他変数は保持）
    val = updates[key].replace('"', '\\"')
    new_lines.append(f'{prefix}{key}="{val}"\n')
    found[key] = True

# 未定義なら追記（ファイル末尾）
append_lines = []
for k, v in updates.items():
    if not found[k]:
        v = v.replace('"', '\\"')
        append_lines.append(f'{k}="{v}"\n')

if append_lines:
    new_lines.append("\n# --- injected by scripts/update_env.sh ---\n")
    new_lines.extend(append_lines)

with open(env_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print("[INFO] Updated 00_env.sh variables:")
for k in updates:
    print(f"  - {k} = {updates[k]}")
PY

## ■ EX（余裕があれば）
1台のサーバー上で knowledge を構築するシェルスクリプトを作成してください。

・実行時に発生しうるエラーは出来るだけ対処すること</br>
・何度実行してもサーバーが正常に稼働できるようにすること</br>
・可読性、再利用性ができるだけ高くなるようなスクリプトにすること</br>
</br>

```bash
# shell作成
vi setup_knowledge.sh
```

```bash
#!/bin/bash

# =============================
# 対話型
# =============================
echo "インストールしたいJDKのURLを入力してください"
read JDK_TAR_URL
echo

echo "インストールしたいTomcatのURLを入力してください"
read TOMCAT_TAR_URL
echo

echo "インストールしたいknowledgeのURLを入力してください"
read KNOWLEDGE_WAR_URL
echo

echo "インストールサーバのパブリックIPを入力してください"
read EC2_PUBLIC_IP
echo

# =============================
# 変数（必要ならここだけ変更）
# =============================
# JDK
JDK_TAR_FILE=`basename "$JDK_TAR_URL"`
JDK_INSTALL_DIR="/opt"                  # /opt 配下に展開
JAVA_PROFILE="/etc/profile.d/java8.sh"  # PATH永続化先（bash_profileより安全）

# Tomcat
TOMCAT_TAR_FILE=`basename "$TOMCAT_TAR_URL"`
TOMCAT_BASE="/usr/local"
TOMCAT_LINK="${TOMCAT_BASE}/tomcat"

# knowledge
APP_NAME="knowledge"
KNOWLEDGE_WEBAPPS_DIR="${TOMCAT_LINK}/webapps"
KNOWLEDGE_APP_DIR="${KNOWLEDGE_WEBAPPS_DIR}/${APP_NAME}"
KNOWLEDGE_WAR_FILE=`basename "$KNOWLEDGE_WAR_URL"`

APACHE_CONF="/etc/httpd/conf/httpd.conf"
SYSTEMD_UNIT="/etc/systemd/system/tomcat.service"

# =============================
# rootチェック
# =============================
if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: rootで実行してください（sudo su - してから実行）"
  exit 1
fi

echo "=== Tomcat + Knowledge セットアップ開始 ==="

# =============================
# 1) JDKインストール（Amazon Corretto 8）
# =============================
cd /tmp

echo "--- JDK ダウンロード ---"
wget "$JDK_TAR_URL"

echo "--- JDK 展開 ---"
tar zxf "$JDK_TAR_FILE"

# 展開されたディレクトリ名を自動取得（バージョン固定を避ける）
JDK_EXTRACTED_DIR="$(tar tzf "$JDK_TAR_FILE" | head -1 | cut -d/ -f1)"
JDK_FULL_PATH="${JDK_INSTALL_DIR}/${JDK_EXTRACTED_DIR}"

if [ ! -d "$JDK_FULL_PATH" ]; then
  echo "--- JDK を /opt に配置 ---"
  rm -rf "$JDK_FULL_PATH" || true
  mv "$JDK_EXTRACTED_DIR" "$JDK_INSTALL_DIR/"
fi

echo "--- JAVA_HOME/PATH 永続化（/etc/profile.d） ---"
cat > "$JAVA_PROFILE" <<EOF
export JAVA_HOME="${JDK_FULL_PATH}"
export PATH="\$PATH:\$JAVA_HOME/bin"
EOF
chmod 644 "$JAVA_PROFILE"

# 現シェルにも反映（以降 jar コマンド等を使えるように）
# shellcheck disable=SC1090
source "$JAVA_PROFILE"

# JDKエラーハンドリング
if ! command -v java >/dev/null 2>&1; then
  echo "ERROR: java コマンドが見つかりません"
  echo "JDKがインストールされていないか、PATHが通っていません"
  exit 1
fi

java -version

# =============================
# 2) Tomcat インストール
# =============================
echo "--- tomcatユーザ作成（存在しなければ） ---"
id tomcat >/dev/null 2>&1 || useradd -s /sbin/nologin tomcat

cd /tmp
echo "--- Tomcat ダウンロード ---"
wget "$TOMCAT_TAR_URL"

echo "--- Tomcat 展開 ---"
tar zxf "$TOMCAT_TAR_FILE"

echo "--- Tomcat 配置 ---"
# 展開されたディレクトリ名を自動取得（バージョン固定を避ける）
TOMCAT_EXTRACTED_DIR="$(tar tzf "$TOMCAT_TAR_FILE" | head -1 | cut -d/ -f1)"
TOMCAT_FULL_PATH="${TOMCAT_BASE}/${TOMCAT_EXTRACTED_DIR}"

if [ ! -d "$TOMCAT_FULL_PATH" ]; then
  mv "$TOMCAT_EXTRACTED_DIR" "$TOMCAT_BASE/"
fi

echo "--- 所有者変更 ---"
chown -R tomcat:tomcat "$TOMCAT_FULL_PATH"

echo "--- シンボリックリンク作成 ---"
ln -sfn "$TOMCAT_FULL_PATH" "$TOMCAT_LINK"

# setenv.sh 作成
echo "--- setenv.sh 作成 ---"
cat > "${TOMCAT_LINK}/bin/setenv.sh" <<EOF
#!/bin/sh
export CATALINA_HOME="${TOMCAT_LINK}"
export JAVA_HOME="${JDK_FULL_PATH}"
export JAVA_OPTS="-Xms128m -Xmx512m"
EOF
chown tomcat:tomcat "${TOMCAT_LINK}/bin/setenv.sh"
chmod 755 "${TOMCAT_LINK}/bin/setenv.sh"

# server.xml バックアップ＆ autoDeploy/unpackWARs を false
echo "--- server.xml バックアップ＆設定変更 ---"
SERVER_XML="${TOMCAT_LINK}/conf/server.xml"
if [ -f "$SERVER_XML" ] && [ ! -f "${SERVER_XML}.bk" ]; then
  cp -a "$SERVER_XML" "${SERVER_XML}.bk"
fi

# Hostタグ内の unpackWARs/autoDeploy を false に（すでにfalseならそのまま）
# ※ 元の値がtrue/falseどちらでも上書きする
sed -i \
  -e 's/unpackWARs="[^"]*"/unpackWARs="false"/' \
  -e 's/autoDeploy="[^"]*"/autoDeploy="false"/' \
  "$SERVER_XML"

# =============================
# 3) systemd ユニット作成
# =============================
echo "--- tomcat.service 作成 ---"
cat > "$SYSTEMD_UNIT" <<EOF
[Unit]
Description=Apache Tomcat 9
After=network.target

[Service]
User=tomcat
Group=tomcat
Type=oneshot
PIDFile=${TOMCAT_LINK}/tomcat.pid
RemainAfterExit=yes

EnvironmentFile=-${JAVA_PROFILE}
ExecStart=${TOMCAT_LINK}/bin/startup.sh
ExecStop=${TOMCAT_LINK}/bin/shutdown.sh
ExecReload=${TOMCAT_LINK}/bin/shutdown.sh ; ${TOMCAT_LINK}/bin/startup.sh

[Install]
WantedBy=multi-user.target
EOF

chmod 755 "$SYSTEMD_UNIT"

systemctl daemon-reload
systemctl enable --now tomcat

# =============================
# 4) Apache(httpd) インストール＆Proxy設定
# =============================
echo "--- httpd & proxy モジュール ---"
dnf -y install httpd

# Proxy設定が未追加なら追記
echo "--- httpd.conf に ProxyPass 追記 ---"
if ! grep -q 'ProxyPass /knowledge' "$APACHE_CONF"; then
  cat >> "$APACHE_CONF" <<'EOF'

# --- Reverse Proxy for Knowledge ---
ProxyRequests Off
ProxyPass /knowledge http://127.0.0.1:8080/knowledge
ProxyPassReverse /knowledge http://127.0.0.1:8080/knowledge
EOF
fi

systemctl enable --now httpd

# =============================
# 5) Knowledge 配置
# =============================
echo "--- Knowledge 配置 ---"
mkdir -p "$KNOWLEDGE_APP_DIR"
cd "$KNOWLEDGE_APP_DIR"

# warを配置して展開（既に展開済みならスキップしたい場合は条件追加可）
wget "$KNOWLEDGE_WAR_URL"

# jar コマンドで展開（JAVA_HOME入っていれば使える）
jar xf "$KNOWLEDGE_WAR_FILE"
rm -f "$KNOWLEDGE_WAR_FILE"

chown -R tomcat:tomcat "$KNOWLEDGE_APP_DIR"

echo "--- tomcat 再起動 ---"
systemctl restart tomcat

echo "=== 完了 ==="
echo "確認URL:"
echo "  Tomcat直:  http://${EC2_PUBLIC_IP}:8080/knowledge"
echo "  Apache経由: http://${EC2_PUBLIC_IP}/knowledge"
echo ""
echo "※ セキュリティグループ: 80(HTTP) と必要なら 8080 を許可"
```

```bash
# shell実行
sudo sh setup_knowledge.sh
```
</br>
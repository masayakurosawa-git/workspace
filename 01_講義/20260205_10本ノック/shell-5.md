## ■ Shell-5
CPUの使用率求めて、その結果をHTMLとして出力して</br>
webサイトから見られるようにしてください</br>
/var/www/html/自分の名前/index.html（デザインはこらなくて良いです）

```bash
# シェル作成
vi cpu_to_html.sh
-------------------------
#!/bin/sh

# 変数定義
EC2_PUBLIC_IP="$1"
USER_NAME="$2"
ROOT_DIRECTORY="/var/www/html"
OUT_HTML_DIR="$ROOT_DIRECTORY/$USER_NAME"
OUT_HTML_FILE="cpu.html"


# Apacheインストール
echo "=== [開始]Apacheインストール ==="
sudo dnf upgrade -y
sudo dnf install -y httpd

# 起動
sudo systemctl enable httpd
sudo systemctl start httpd
echo "=== [終了]Apacheインストール ==="


# HTML出力先チェック
echo "=== [開始]HTML出力先チェック ==="
if [ -d "$OUT_HTML_DIR" ]
then
    echo "HTML出力先は存在します"
    echo "HTML出力先：$OUT_HTML_DIR"
else
    echo "HTML出力先を作成します"
    mkdir "$OUT_HTML_DIR"
    if [ $? = 1 ]
    then
        echo "$OUT_HTML_DIRの作成に失敗しました"
    fi
fi
echo "=== [終了]HTML出力チェック ==="


# CPU使用率を取得
echo "=== [開始]CPU使用率取得 ==="
# 平均CPU使用率を算出（vmstatは最初の2行はヘッダ＆初期値なので除外）
CPC_USAGE=$(vmstat 1 5 | awk '
NR>2 { usage += (100 - $15); count++ }
END   { if (count==0) print "0.00"; else printf "%.2f", usage/count }
')

TS="$(date '+%Y-%m-%d %H:%M:%S %Z')"
HOST="$(hostname -f 2>/dev/null || hostname)"
echo "=== [終了]CPU使用率取得 ==="


# HTML出力
echo "=== [開始]HTML出力 ==="
cat > "$OUT_HTML_DIR/$OUT_HTML_FILE" <<HTML
<!doctype html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="10">
  <title>CPU平均使用率（直近5秒）</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; margin: 24px; }
    .card { border: 1px solid #ddd; border-radius: 12px; padding: 16px; max-width: 560px; }
    .big { font-size: 44px; font-weight: 800; }
    .meta { color: #555; margin-top: 8px; }
    .bar { height: 14px; background: #eee; border-radius: 999px; overflow: hidden; margin-top: 12px; }
    .bar > div { height: 100%; width: ${CPC_USAGE}%; background: #4f46e5; }
  </style>
</head>
<body>
  <h1>CPU平均使用率（直近5秒）</h1>
  <div class="card">
    <div class="big">${CPC_USAGE}%</div>
    <div class="bar"><div></div></div>
    <div class="meta">Host: ${HOST}</div>
    <div class="meta">Updated: ${TS}</div>
  </div>
</body>
</html>
HTML

# ファイル確認
if [ -f "$OUT_HTML_DIR/$OUT_HTML_FILE" ]
then
    echo "HTMLを作成しました"
else
    echo "HTMLの作成に失敗しました"
    exit 1
fi
echo "=== [終了]HTML出力 ==="


# html権限変更
sudo chown -R apache:apache /var/www/html/
sudo chmod -R 755 /var/www/html/

# 完了

echo "======================================="
echo "ブラウザで以下にアクセスしてください"
echo "http://${EC2_PUBLIC_IP}/${USER_NAME}/${OUT_HTML_FILE}"
echo "（もし表示されない場合は、SGで80番が許可されているか確認）"
echo "======================================="

exit 0
-------------------------


# シェル実行
sudo sh cpu_to_html.sh 52.32.6.210 kurosawa


# ブラウザ確認

```
</br>
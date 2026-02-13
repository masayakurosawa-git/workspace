## ■ Shell-7
サイトの証明書を確認して、残り日数をブラウザで確認できるようにしてください。

・確認は下記の表のように html で表示すること</br>
・残りが2週間を切っていたら赤く表示すること</br>
※HTMLの書き方を調べる必要があります。</br>

| サイト      | 日数 |
|------------|-----|
|yahoo.co.jp | 22 |
|rakus.co.jp | 18 |
|facebook.com | 4 |


```bash
vi domain_days_check.sh
-------------------------
#!/bin/sh

# 変数定義
DOMAIN_LIST="/home/ec2-user/domain_days_check.list"
EC2_PUBLIC_IP="$1"
USER_NAME="$2"
ROOT_DIRECTORY="/var/www/html"
OUT_HTML_DIR="$ROOT_DIRECTORY/$USER_NAME"
OUT_HTML_FILE="domain.html"
OUT_HTML_PATH="$OUT_HTML_DIR/$OUT_HTML_FILE"


# リストファイルの有無
echo "=== リストファイル確認 ==="
if [ ! -f "$DOMAIN_LIST" ]; then
  echo "リストがありません"
  exit 1
fi


# HTML出力先の有無確認
echo "=== HTML出力先チェック ==="
if [ ! -d "$OUT_HTML_DIR" ]
then
    echo "HTML出力先を作成します"
    mkdir "$OUT_HTML_DIR"
    if [ $? = 1 ]
    then
        echo "$OUT_HTML_DIR の作成に失敗しました"
        exit 1
    fi
fi

# HTML開始
cat > "$OUT_HTML_PATH" <<EOF
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8">
  <title>証明書残日数</title>
  <style>
    body { font-family: system-ui, -apple-system, sans-serif; margin: 24px; }
    table { border-collapse: collapse; width: 520px; }
    th, td { border: 1px solid #999; padding: 8px 10px; }
    th { background: #f3f4f6; text-align: left; }
    td.days { text-align: right; width: 120px; }
    .warn { color: red; font-weight: 700; }
  </style>
</head>
<body>
  <h2>証明書残日数</h2>
  <table>
    <tr>
      <th>サイト</th>
      <th>日数</th>
    </tr>
EOF


# 証明書の有効日数を取得
echo "=== サイト監視 ==="
while read DOMAIN
do
    # 空行・コメント行はスキップ
    [ -z "$DOMAIN" ] && continue
    echo "$DOMAIN" | grep -q '^\s*#' && continue

    # 有効期限
    end_date=$(
    echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null \
        | openssl x509 -noout -enddate \
        | cut -d= -f2
    )

    # 有効期限をUnix時間に変換
    end_epoch=$(date -d "$end_date" +%s)

    # 現在時刻をUnix時間に変換
    now_epoch=$(date +%s)

    # 残日数
    remain_days=$(( (end_epoch - now_epoch) / 86400 ))

    # 表示
    printf "DOMAIN=%-25s | EXPIRES=%-25s | REMAIN=%4s days\n" "$DOMAIN" "$end_date" "$remain_days"

    # 14日未満は赤（2週間切り）
    if [ "$remain_days" -lt 14 ]; then
        echo "<tr><td>$DOMAIN</td><td class='days warn'>$remain_days</td></tr>" >> "$OUT_HTML_PATH"
    else
        echo "<tr><td>$DOMAIN</td><td class='days'>$remain_days</td></tr>" >> "$OUT_HTML_PATH"
    fi

done < "$DOMAIN_LIST"

# HTML終了
cat >> "$OUT_HTML_PATH" <<EOF
</table>
</body>
</html>
EOF

echo "HTML出力完了: $OUT_HTML_PATH"
echo "http://$EC2_PUBLIC_IP/$USER_NAME/$OUT_HTML_FILE"
-------------------------

sh domain_days_check.sh 52.32.6.210 kurosawa
```
</br>
## ■ Shell-6
下記コマンドを使って3〜4サイトを監視するスクリプトを作成してください

curl -IL 監視したいURL -o /dev/null -w "%{http_code}\n" -s

・if と for を使うこと</br>
・監視するサイトは site.list というファイルを使ってシェルから読み込むこと</br>
・監視結果があとで見られるようにログを出力する機能をつけてください</br>

```bash
vi request_http.sh
-------------------------
#!/bin/sh

# 変数定義
REQUEST_LIST="/home/ec2-user/request_http.list"
LOG_DIR="/home/ec2-user/log"
LOG_FILE="request_http.log"


# リストファイルの有無
echo "=== リストファイル確認 ==="
if [ -f "$REQUEST_LIST" ]
then
    echo "リストファイルは存在します"
else
    echo "リストファイルは存在しません"
    echo "リストファイルを作成してください"
    exit 1
fi


# logディレクトリの有無確認
echo "=== logディレクトリ確認 ==="
if [ -d "$LOG_DIR" ]
then
    echo "logディレクトリは存在します"
    echo "logディレクトリ：$LOG_DIR"
else
    echo "logディレクトリを作成します"
    mkdir "$LOG_DIR"
    if [ $? = 1 ]
    then
        echo "$LOG_DIR の作成に失敗しました"
    fi
fi


# サイト監視(リクエスト送信)
echo "=== サイト監視 ==="
while read LINE
do
    # 定義
    REQUEST_URL="$LINE"
    LOG_FILE_PASS="$LOG_DIR/$LOG_FILE"

    # リクエスト送信 → ステータスコード取得
    STATUS=`curl -LI "$REQUEST_URL" -o /dev/null -w '%{http_code}\n' -s`

    # ステータスコード変換
    case "$STATUS" in
    200)
        RESULT="OK"
        ;;
    301|302)
        RESULT="REDIRECT"
        ;;
    400|401|403|404)
        RESULT="CLIENT_ERROR"
        ;;
    500|502|503)
        RESULT="SERVER_ERROR"
        ;;
    000)
        RESULT="NO_CONNECT"
        ;;
    *)
        RESULT="UNKNOWN"
        ;;
    esac

    # コンソールに結果表示
    echo "[$RESULT]$STATUS | $REQUEST_URL"

    # ログファイルに出力
    printf "%-19s | %-40s | %3s | %-12s\n" \
    "$(date '+%Y-%m-%d %H:%M:%S')" \
    "$REQUEST_URL" \
    "$STATUS" \
    "$RESULT" >> "$LOG_DIR/$LOG_FILE"

done < "$REQUEST_LIST"


# ログファイル有無を確認
if [ -f "$LOG_DIR/$LOG_FILE" ]
then
    echo "$LOG_DIR/$LOG_FILE が作成されました"
    exit 0
else
    echo "$LOG_DIR/$LOG_FILE の作成に失敗しました"
    exit 1
fi
-------------------------

sh request_http.sh
```
</br>
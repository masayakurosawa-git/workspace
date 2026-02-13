## ■ Shell-4
下記2つの要件を満たすシェルを書いてみてください。

・backup.list ファイルに記載されたファイル名をバックアップしてくれる仕組み</br>
・バックアップしたファイルがちゃんと存在するかチェックする仕組み

引数と対話形式は今回使わない。シェルを引数無しで実行し、上記が実行されること
</br>
</br>

```bash
# リストファイル作成
touch /home/ec2-user/kurosawa/backup.list
echo "/etc/httpd/conf.d/README" >> /home/ec2-user/kurosawa/backup.list
echo "/etc/httpd/conf.d/autoindex.conf" >> /home/ec2-user/kurosawa/backup.list
echo "/etc/httpd/conf.d/userdir.conf" >> /home/ec2-user/kurosawa/backup.list
echo "/etc/httpd/conf.d/welcome.conf" >> /home/ec2-user/kurosawa/backup.list
```

```bash
# シェル作成
vi readline_file_backup.sh
```

```bash
#!/bin/sh

# 変数定義
BK_LIST="/home/ec2-user/kurosawa/backup.list"
BK_DIR="/home/ec2-user/kurosawa/backup2"

# バックアップ先の有無確認
echo "=== バックアップ先確認 ==="
if [ -d "$BAK_DIR" ]
then
    echo "バックアップ先は存在します"
    echo "バックアップ先：$BAK_DIR"
else
    echo "バックアップ先を作成します"
    mkdir "$BAK_DIR"
fi
echo "=== バックアップ先終了 ==="

# バックアップ作成
echo "=== バックアップ作成を開始します ==="
while read LINE
do
    # 定義
    ORIGIN_FILE_PASS="$LINE"
    ORIGIN_FILE=`basename "$ORIGIN_FILE_PASS"`
    BK_FILE="$ORIGIN_FILE.`date +"%Y%m%d%H%M%S"`.bak"
    
    # ファイルコピー
    cp -a "$ORIGIN_FILE_PASS" "$BK_DIR/$BK_FILE"
    
    # ファイルチェック
    if [ -f "$BK_DIR/$BK_FILE" ]
    then
        echo "$BK_DIR/$BK_FILEが作成されました"
    else
        echo "$BK_DIR/$BK_FILEの作成に失敗しました"
        exit 1　
    fi
done < "$BK_LIST"
echo "=== バックアップ作成を終了します ==="
exit 0
```

```bash
# シェル実行
sudo sh readline_file_backup.sh
```

</br>

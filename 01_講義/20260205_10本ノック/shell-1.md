## ■ Shell-1
下記ファイルをバックアップするシェルを作成せよ

・バックアップ先のファイル名は httpd.conf.202201011212.bak といった、年月日時分秒のフォーマットで作成すること</br>
・バックアップ元とバックアップ先ディレクトリは変数で定義すること

バックアップ元：/etc/httpd/conf/httpd.conf
</br>
バックアップ先：/home/ec2-user/自分の名前/backup/

</br>
</br>


```bash
# シェル作成
vi httpd_bak.sh
```


```bash
#!/bin/sh

# 変数定義
ORIGIN_FILE_PASS="/etc/httpd/conf/httpd.conf"
ORIGIN_DIR=`dirname $ORIGIN_FILE_PASS`
ORIGIN_FILE=`basename $ORIGIN_FILE_PASS`
BAK_DIR="/home/ec2-user/kurosawa/backup"

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
BAK_FILE="$ORIGIN_FILE.`date +"%Y%m%d%H%M%S"`.bak"
cp -a "$ORIGIN_DIR/$ORIGIN_FILE" "$BAK_DIR/$BAK_FILE"
if [ -f "$BAK_DIR/$BAK_FILE" ]
then
    echo "$BAK_DIR/$BAK_FILEが作成されました"
    exit 0
else
    echo "$BAK_DIR/$BAK_FILEの作成に失敗しました"
    exit 1
fi
```


```bash
# シェル実行
sudo sh httpd_bak.sh
```

</br>
## ■ Shell-2
お題1で作成したシェルに汎用性をもたせてください。具体的には下記を実装する。

・1つ目の引数で、バックアップ元のファイルを指定</br>
・2つ目の引数で、バックアップ先のディレクトリを指定

上記実装した上で、バックアップ元を /etc/named.conf でバックアップできればOK

</br>
</br>


```bash
# シェル作成
vi named_bak.sh
```



```bash
#!/bin/sh

# 変数定義
ORIGIN_FILE_PASS="$1"
BAK_DIR="$2"
ORIGIN_DIR=`dirname $ORIGIN_FILE_PASS`
ORIGIN_FILE=`basename $ORIGIN_FILE_PASS`

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
cp -a "$ORIGIN_FILE_PASS" "$BAK_DIR/$BAK_FILE"
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
# sh named_bak.sh {コピー元} {コピー先}
sh named_bak.sh /etc/named.conf /home/ec2-user/kurosawa/backup
```

</br>
## ■ Shell-3
15-2で作成したスクリプトを、引数を使わずに対話形式で実装してください

例）</br>
バックアップ元は？　xxxxx</br>
バックアップ先は？　xxxx</br>
xxxx をバックアップしました。
</br>
</br>


```bash
# シェル作成
vi read_bak.sh
```


```bash
#!/bin/sh

# 対話形式で定義
echo "バックアップ元は？"
read ORIGIN_FILE_PASS

echo "バックアップ先は？"
read BAK_DIR

echo
echo "=============================="
echo "バックアップ元 : ${ORIGIN_FILE_PASS}"
echo "バックアップ先 : ${BAK_DIR}"
echo "=============================="
read -p "この内容で続行しますか？ (y/N): " CONFIRM
[[ "${CONFIRM:-}" =~ ^[Yy]$ ]] || { echo "中止しました。"; exit 1; }

# 変数定義
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
-------------------------



```


```bash
# シェル実行
sh read_bak.sh

/etc/named.conf
/home/ec2-user/kurosawa/backup
```

</br>
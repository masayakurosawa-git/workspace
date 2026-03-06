## 作業ディレクトリの作成
任意の場所で以下ディレクトリを作成
```bash
mkdir works
```

## 初回（clone）
```bash
git clone git@github.com:masayakurosawa-git/teame-docs.git
cd teame-docs
```

## 変更 → コミット
```bash
git status
git add .
git commit -m "docs: 初回コミット"
```

## pull
ローカルとリモートの状態を揃える。
```bash
git pull --rebase origin main
```

## push
```bash
git push -u origin main
```



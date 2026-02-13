# GeminiCLI 構築手順
<br/>

## 3. Gemini CLI を使ってみよう
### 3.1. Node.js を使ったインストール
#### Node.js がインストールされているか確認するには、以下のコマンドを実行します。
```bash
node -v

# バージョンが表示されれば問題なし。
-------------------------------
[kurosawamasaya@kurosawamasayanoMacBook-Pro ~]$ node -v
v24.13.0
[kurosawamasaya@kurosawamasayanoMacBook-Pro ~]$ 
-------------------------------
```
<br/>

#### Node.js がインストールされていれば、以下のコマンドで Gemini CLI をインストールできます。
```bash
# インストール
npm install -g @google/gemini-cli

# 確認
gemini
```
<br/>

#### インストール後、コマンドを実行します。
```bash
gemini
```
<br/>
<br/>


### 3.2. 初期設定
#### 1. Google アカウントでログインします。
`Login with Google` を選択し、Enter キーを押します。ブラウザが開き、Google アカウントの認証画面が表示されます。

#### 2. 認証が完了すると、Gemini CLI 専用のコンソールが表示されます。
```bash
> Type your message or @path/to/file
```

#### 3. 表示されるテーマを選択します。
```bash
/theme
```
矢印キーで選択し、Enter キーで決定します。他の設定には Tab キーで移動できます。
<br/>
<br/>
以上で初期設定は完了です。`/quit` と入力してコンソールを終了します。
<br/>
<br/>
<br/>
<br/>

### 3.3. 安全に使うための設定
#### ユーザーの設定ファイル
Gemini CLI を安全に使うために、最初に設定を行います。`~/.gemini/settings.json` ファイルをエディタで開き、以下の内容を記述します。
```bash
# バックアップ作成
cp -a ~/.gemini/settings.json

# ファイル編集
vi ~/.gemini/settings.json
-------------------------------
{
  "general": {
    "checkpointing": {
      "enabled": true // チェックポイント有効
    }
  },
  "security": {
    "auth": {
      "selectedType": "oauth-personal" // ログイン方法
    }
  },
  "ui": {
    "theme": "GitHub Light" // 選択したテーマ
  }
}
-------------------------------
```






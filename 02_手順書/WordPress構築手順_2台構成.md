# 概要
### 目的
ログイン画面が表示されることがゴール。

### 2回目
EC2①にApache、php、wordpressを構築</br>
EC2②にmariadbを構築
</br>
</br>

# 全体構成
```bash
[ EC2① ] Web + WordPress
   |
   | 3306/TCP
   v
[ EC2② ] MariaDB（DB専用）
```
</br>
</br>

# 手順
## ステップ1: 【EC2②】MariaDBのインストール
### 1. EC2②インスタンスを作成
AWSコンソールから作成
</br>
</br>


### 2. EC2②インスタンスに接続
```bash
ssh -i ~/.ssh/CL_kurosawa.pem ec2-user@18.236.92.68
```
</br>


### 3. すべてのソフトウェアパッケージが最新の状態であることを確認する
```bash
sudo dnf upgrade -y
```
</br>


### 4. MariaDB ソフトウェアパッケージをインストール
※ dnf install コマンドを使用すると、複数のソフトウェアパッケージと関連するすべての依存関係を同時にインストールできます。
```bash
# インストール
sudo dnf install mariadb105-server

# パッケージの現在のバージョンを表示
sudo dnf info mariadb105

# 起動
sudo systemctl start mariadb
sudo systemctl enable mariadb
sudo systemctl is-enabled mariadb
sudo systemctl status mariadb
```
</br>


### 5. mysql_secure_installation を実行します。(セキュリティ保護)
```bash
sudo mysql_secure_installation
pass: kurosawa
```
</br>


### 6. MariaDB の起動
```bash
# 起動
sudo systemctl start mariadb

# 自動起動
sudo systemctl enable mariadb

# 自動起動の設定確認
sudo systemctl is-enabled mariadb

# 状態確認
sudo systemctl status mariadb
```
</br>


### 7. MariaDB が外部接続を受け付けるように設定変更
```bash
# バックアップ
sudo cp -a /etc/my.cnf.d/mariadb-server.cnf /etc/my.cnf.d/mariadb-server.cnf.`date +"%Y%m%d_%H%M%S"`.bak

# 設定変更
sudo vi /etc/my.cnf.d/mariadb-server.cnf
------------------------------
[mysqld]
bind-address=0.0.0.0
------------------------------
```
</br>


### 8. MariaDB の設定を反映
```bash
# 反映
sudo systemctl restart mariadb

# 状態確認
sudo systemctl status mariadb
```
</br>


### 9. EC2②のセキュリティグループのインバウンドルールにhttp(ポート80)を追加。
```bash
Type: MYSQL/Aurora
Port: 3306
Protocol: TCP
Source: {EC2①のセキュリティグループ}
```
</br>






## ステップ2: 【EC2②】DB・ユーザ作成
### 1. データベースサーバーに root ユーザーとしてログインします。
```bash
mysql -u root -p
```
</br>


### 2. MySQL データベースのユーザーとパスワードを作成します。
```bash
# ユーザ作成
CREATE USER 'kurosawa'@'%' IDENTIFIED BY 'kurosawa';
※ % は「EC2①からの接続を許可する」意味

# 確認
select user, host from mysql.user;
```
</br>


### 3. データベースを作成します。
```bash
# DB作成
CREATE DATABASE `wordpress-db`;

# 確認
show databases;
```
</br>


### 4. データベースに対して、以前作成した WordPress ユーザーに対する完全な権限を付与します。
```bash
# 権限付与
GRANT ALL PRIVILEGES ON `wordpress-db`.* TO "kurosawa"@"%";
※ % は「EC2①からの接続を許可する」意味
```
</br>


### 5. すべての変更を有効にするため、データベース権限をフラッシュします。
```bash
FLUSH PRIVILEGES;
```
</br>


### 6. mysqlからログアウト
```bash
exit
```
</br>




## ステップ3: 【EC2①】WordPressの設定変更
### 1. EC2①インスタンスに接続
```bash
ssh -i ~/.ssh/CL_kurosawa.pem ec2-user@35.86.176.24
```
</br>


### 2. wp-config.php を修正
```bash
# バックアップ作成
cp -a /var/www/html/wp-config.php /var/www/html/wp-config.php.`date +"%Y%m%d_%H%M%S"`.bak

# 設定編集
vi /var/www/html/wp-config.php
------------------------------
define('DB_NAME', 'wordpress-db2');
define('DB_USER', 'kurosawa2');
define('DB_PASSWORD', 'kurosawa2');
define('DB_HOST', '172.31.23.106');
------------------------------
↑ EC2②のプライベートIP
```
</br>


### 3. MariaDB クライアントで疎通確認
```bash
mysql -h 172.31.23.106 -u kurosawa2 -p wordpress-db2
```
</br>




## ステップ4: 稼働確認
### 1. WordPressにアクセス
```bash
http://35.86.176.24/
```
</br>





# 専門用語
- LAMPサーバ：
オープンソースソフトウェアの組み合わせを指す言葉（略称）です。
具体的にはOSのLinux、WebサーバーのApache、データベースのMySQL、プログラミングのPerl、PHP、Pythonを指します。
https://www.idcf.jp/words/lamp.html


# 参考サイト
1. AL2023 に LAMP サーバーをインストールする
https://docs.aws.amazon.com/ja_jp/linux/al2023/ug/ec2-lamp-amazon-linux-2023.html

2. AL2023 で WordPress ブログをホストする
https://docs.aws.amazon.com/ja_jp/linux/al2023/ug/hosting-wordpress-aml-2023.html
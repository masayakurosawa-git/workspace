# 概要
- 目的
ログイン画面が表示されることがゴール。
- 1回目
EC2①にApache、php、wordpress、mariadbを構築



# 手順
## ステップ1: LAMP サーバーを準備する
1. EC2インスタンスに接続
ssh -i ~/.ssh/CL_kurosawa.pem ec2-user@35.86.176.24


2. すべてのソフトウェアパッケージが最新の状態であることを確認する
sudo dnf upgrade -y


3. Apache ウェブサーバーの最新バージョンと AL2023 用の PHP パッケージをインストール
sudo dnf install -y httpd wget php-fpm php-mysqli php-json php php-devel


4. MariaDB ソフトウェアパッケージをインストール
※ dnf install コマンドを使用すると、複数のソフトウェアパッケージと関連するすべての依存関係を同時にインストールできます。
sudo dnf install mariadb105-server

パッケージの現在のバージョンを表示
sudo dnf info {package_name}


5. Apache ウェブサーバーを起動
sudo systemctl start httpd


6. Apache ウェブサーバーを自動起動するように設定
sudo systemctl enable httpd
自動起動の設定確認
sudo systemctl is-enabled httpd


7. セキュリティグループのインバウンドルールにhttp(ポート80)を追加。
Type: HTTP
Port: 80
Protocol: TCP
Source: {マイIP}


8. ドキュメントルート「/var/www/html」の所有者を root → ec2-user に変更
→ ec2-user (および apache グループの将来のメンバー) は、Apache ドキュメントルートでファイルを追加、削除、編集できるようになります。したがって、静的ウェブサイトや PHP アプリケーションなどのコンテンツを追加できます。

- ユーザー (この場合は ec2-user) を apache グループに追加します。
sudo usermod -a -G apache ec2-user

- ログアウトし、再度ログインして新しいグループを選択し、メンバーシップを確認します。
a. ログアウト
exit

b. apache グループのメンバーシップを検証するには、インスタンスに再接続して次のコマンドを実行します。
groups
※ 実行結果に「apache」が含まれていることを確認
----------------------------------------
[ec2-user@ip-172-31-22-120 ~]$ groups
ec2-user adm wheel apache systemd-journal
[ec2-user@ip-172-31-22-120 ~]$ 
----------------------------------------

-  /var/www とそのコンテンツのグループ所有権を apache グループに変更します。
sudo chown -R ec2-user:apache /var/www

- グループの書き込み許可を追加して、これからのサブディレクトにグループ ID を設定するには、/var/www とサブディレクトのディレクトリ許可を変更します。
sudo chmod 2775 /var/www && find /var/www -type d -exec sudo chmod 2775 {} \;

- グループ書き込み許可を追加するには、/var/www とサブディレクトリのファイル許可を再帰的に変更します。
find /var/www -type f -exec sudo chmod 0664 {} \;


## ステップ2: LAMP サーバーをテストする
1. Apache ドキュメントルートで PHP ファイルを作成します。
echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php

2. ウェブブラウザで、作成したファイルの URL を入力します。
http://35.86.176.24/phpinfo.php

3. phpinfo.php ファイルを削除
rm /var/www/html/phpinfo.php


## ステップ3: データベースサーバーをセキュリティで保護する
1. MariaDB サーバーを起動します。
sudo systemctl start mariadb

2. mysql_secure_installation を実行します。
sudo mysql_secure_installation

3. ブート時(OS起動時)に毎回 MariaDB サーバーを起動させる場合は、次のコマンドを入力します。
sudo systemctl enable mariadb
sudo systemctl is-enabled mariadb


## ステップ4: (オプション) phpMyAdmin をインストールする
コマンドラインからログインするため、実施不要




## WordPress のインストール
1. パッケージをダウンロードしてインストール
sudo dnf install wget php-mysqlnd -y


2. 最新の WordPress インストールパッケージをダウンロード
wget https://wordpress.org/latest.tar.gz


3. インストールパッケージを解凍します。
tar -xzf latest.tar.gz


4. データベースおよびウェブサーバーを起動します。
sudo systemctl start mariadb httpd


5. データベースサーバーに root ユーザーとしてログインします。
mysql -u root -p
{pass入力}


6. MySQL データベースのユーザーとパスワードを作成します。
CREATE USER 'wordpress-user'@'localhost' IDENTIFIED BY 'your_strong_password';
select user, host from mysql.user;


7. データベースを作成します。
CREATE DATABASE `wordpress-db`;
show databases;


8. データベースに対して、以前作成した WordPress ユーザーに対する完全な権限を付与します。
GRANT ALL PRIVILEGES ON `wordpress-db`.* TO "kurosawa"@"localhost";


9. すべての変更を有効にするため、データベース権限をフラッシュします。
FLUSH PRIVILEGES;


10. mysqlからログアウト
exit


11. wp-config-sample.php ファイルを wp-config.php という名前でコピーします。
※ この操作を実行すると、新しい構成ファイルが作成され、元のファイルがバックアップとしてそのまま保持されます。
cp wordpress/wp-config-sample.php wordpress/wp-config.php


12. インストール用の値を入力します。
vi wordpress/wp-config.php
------------------------------------
define('DB_NAME', 'wordpress-db');
define('DB_USER', 'wordpress-user');
define('DB_PASSWORD', 'your_strong_password');
------------------------------------


13. WordPress ファイルを Apache ドキュメントルートの下に配置
cp -r wordpress/* /var/www/html/


15. httpd.confを編集
sudo cp -a /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bk
sudo vim /etc/httpd/conf/httpd.conf
------------------------------------
<Directory "/var/www/html">を検索
AllowOverride None 行を AllowOverride All に変更
------------------------------------


16. PHP グラフィック描画ライブラリを AL2023 にインストールする
sudo dnf install php-gd
sudo dnf list installed | grep php8.4-gd
------------------------------------
[ec2-user@ip-172-31-22-120 ~]$ sudo dnf list installed | grep php8.4-gd
php8.4-gd.x86_64                          8.4.16-1.amzn2023.0.1              @amazonlinux
[ec2-user@ip-172-31-22-120 ~]$
------------------------------------




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
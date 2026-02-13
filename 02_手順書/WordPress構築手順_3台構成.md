# 概要
- 目的
ログイン画面が表示されることがゴール。
- 3回目
EC2①にApache、wordpressを構築
EC2②にphp、wordpressを構築
EC2③にmariadbを構築



# 全体構成
[ client ]
   |
   | 
   v
[ EC2① ] Apache + WordPress
   |
   | (FastCGI :9000)
   v
[ EC2② ] PHP-FPM + WordPress
   |
   | 3306/TCP
   v
[ EC2③ ] MariaDB（DB専用）



# 手順
## ステップ1: 【EC2③】MariaDBのインストール
1. EC2③インスタンスに接続
ssh -i ~/.ssh/CL_kurosawa.pem ec2-user@18.236.92.68


2. EC2②のセキュリティグループのインバウンドルールを追加。
Type: MYSQL/Aurora
Port: 3306
Protocol: TCP
Source: {EC2②のセキュリティグループ}




## EC2②：PHP-FPM + WordPress
ssh -i ~/.ssh/CL_kurosawa.pem ec2-user@18.236.92.68

1. PHP-FPM と必要拡張を入れる
sudo dnf upgrade -y
sudo dnf install -y php-fpm php-mysqli php-json php-gd php-mbstring php-xml php-opcache wget tar


2. php-fpm を TCP 9000 で待ち受けるようにする
sudo vi /etc/php-fpm.d/www.conf
----------------------------------------
user = apache
group = apache

listen = 0.0.0.0:9000
listen.allowed_clients = EC2①のプライベートIP
----------------------------------------

7. php-fpmを有効化
sudo systemctl enable php-fpm
sudo systemctl status php-fpm


8. ドキュメントルートの権限変更
cd
sudo cp -r wordpress/* /var/www/html/
sudo chown -R apache:apache /var/www/html


9. WordPress を EC2② に配置
cd
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
sudo cp -r wordpress/* /var/www/html/
sudo chown -R apache:apache /var/www/html


10. EC2②の wp-config.php（DBはEC2③へ）
sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
sudo vi /var/www/html/wp-config.php
----------------------------------------
define('DB_NAME', 'wordpress_db2');
define('DB_USER', 'kurosawa2');
define('DB_PASSWORD', 'kurosawa2');
define('DB_HOST', '172.31.23.106');
----------------------------------------
↑ EC2③のプライベートIP


9. すべての変更を有効にするため、データベース権限をフラッシュします。
FLUSH PRIVILEGES;


10. mysqlからログアウト
exit




## EC2①：Apache（Web層）→ EC2② PHP-FPM に転送
1. EC2①インスタンスに接続
ssh -i ~/.ssh/CL_kurosawa.pem ec2-user@54.191.180.178


2. Apache を入れる
sudo dnf upgrade -y
sudo dnf install -y httpd
sudo systemctl enable httpd


3. 必要モジュール確認（proxy_fcgi）
httpd -M | egrep 'proxy|proxy_fcgi'


4. Apache から PHP-FPM へ流す設定を作成
sudo vi /etc/httpd/conf.d/php-fpm-proxy.conf
----------------------------------------
# PHPはEC2②のPHP-FPMへ
<FilesMatch \.php$>
    SetHandler "proxy:fcgi://172.31.47.183:9000"
</FilesMatch>

DirectoryIndex index.php index.html
----------------------------------------


5. SELinux
sudo setsebool -P httpd_can_network_connect 1


6. Apache再起動
sudo systemctl restart httpd
sudo systemctl status httpd 


7. EC2①にも WordPress を置く（静的ファイル配信用）
EC2①で：
sudo rm -rf /var/www/html
sudo mkdir -p /var/www/html
sudo chown -R ec2-user:ec2-user /var/www/html

EC2②で：
rsync -av --delete /var/www/html/ ec2-user@EC2①のプライベートIP:/var/www/html/




## ステップ4: 稼働確認
1. WordPressにアクセス
http://35.86.176.24/





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
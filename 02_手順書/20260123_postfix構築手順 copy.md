# 概要
### 1. postfixを構築する
<br/>
<br/>

# 1. Postfixを構築する
## セキュリティグループにルール追加
以下ルールを追加。
```bash
タイプ: SMTP
プロトコル: TCP
ポート範囲: 25
ソース: 172.31.0.0/16

※ 自分のネットワーク内のメール送受信は許可
```
</br>




## Postfix（送信側）インストール
```bash
# EC2インスタンスに接続
ssh -i ~/.ssh/CL_kurosawa.pem ec2-user@16.148.38.201
ssh -i ~/.ssh/CL_kurosawa_key.pem ec2-user@44.249.83.33


# ユーザスイッチ
sudo su -


# インストール
dnf install postfix


# 起動
systemctl start postfix


# 状態確認
systemctl status postfix
ps -ef | grep postfix
netstat -ln | grep 25


# メール送信コマンドインストール
dnf install mailx
※ このコマンドでメールを操作することが可能。

```
</br>




## Postfixの設定
```bash
# バックアップ作成
cp -a /etc/postfix/main.cf /etc/postfix/main.cf.`date "+%Y%m%d_%H%M%S"`.bak


# 確認
ls -l /etc/postfix/ | grep main
-----------------------------------
[root@ip-172-31-38-31 ~]# ls -l /etc/postfix/ | grep main
-rw-r--r--. 1 root root 29709 Jan 16  2024 main.cf
-rw-r--r--. 1 root root 29709 Jan 16  2024 main.cf.20260123_013804.bak
-rw-r--r--. 1 root root 29470 Jan 16  2024 main.cf.proto
[root@ip-172-31-38-31 ~]# 
-----------------------------------


# コメントアウトの削除（見づらいため）
grep -v ^# /etc/postfix/main.cf | cat -s > /tmp/main.cf
※ cat -s オプションは複数空白行を縮める


# 確認
view /tmp/main.cf


# /tmp/main.cf を /etc/postfix/ にコピー
cp /tmp/main.cf /etc/postfix/main.cf


# Postfixの設定ファイルを編集
vi /etc/postfix/main.cf
-----------------------------------
↓変更
# inet_interfaces = localhost
inet_interfaces = all

# mydestination = $myhostname, localhost.$mydomain, localhost
mydestination = $mydomain, $myhostname

↓追加
# 20260123_add
myhostname = mail.kurosawa.local
mydomain = kurosawa.local
myorigin = $myhostname
mynetworks = 172.31.0.0/16, 172.0.0.1
mail_spool_directory = /var/spool/mail/
-----------------------------------


# postfix を再起動
systemctl restart postfix.service
systemctl status postfix

```
</br>



## DNSサーバの設定
```bash
# bind インストール
dnf install bind


# 設定ファイルのバックアップ
cp -a /etc/named.conf /etc/named.conf.`date "+%Y%m%d_%H%M%S"`.bak


# 確認
ls -l /etc/ | grep named
-----------------------------------
[root@ip-172-31-38-31 ~]# ls -l /etc/ | grep named
drwxr-x---.  2 root named       6 Oct 23 23:36 named
-rw-r-----.  1 root named    1722 Oct 23 23:36 named.conf
-rw-r-----.  1 root named    1722 Oct 23 23:36 named.conf.20260123_024418.bak
-rw-r-----.  1 root named    1034 Oct 23 23:36 named.rfc1912.zones
-rw-r--r--.  1 root named     686 Oct 23 23:36 named.root.key
[root@ip-172-31-38-31 ~]#
-----------------------------------


# 設定ファイルの編集
vi /etc/named.conf
-----------------------------------
↓以下をコメントアウト
listen-on port 53 { 127.0.0.1; };
listen-on-v6 port 53 { ::1; };
〜省略〜
allow-query     { localhost; };

↓追記
allow-query     { any; };

↓zone情報を定義
zone "kurosawa.local" IN {
    type master;
    file "/var/named/kurosawa.local.zone";
};
-----------------------------------


# named.conf の構文チェック
named-checkconf
※ 何も表示がなければOK


# ゾーンファイルの作成
vi /var/named/kurosawa.local.zone
----------------------------------------
$TTL 3600
@ IN SOA ns.kurosawa.local. test.gmail.com. (
20220401 ; serial
3600 ; refresh
3600 ; retry
3600 ; expire
3600 ) ; minimum

        IN NS ns.kurosawa.local.
        IN MX 10 mail.kurosawa.local.
ns      IN A  172.31.38.31
mail     IN A  172.31.38.31
----------------------------------------


# ゾーンファイルの構文チェック
named-checkzone kurosawa.local /var/named/kurosawa.local.zone
※ 何も表示がなければOK


# 再起動
systemctl start named


# 状態確認
systemctl status named | less


# 接続確認
dig @localhost mail.kurosawa.local


# DNSサーバ 設定ファイルのバックアップ
cp -a /etc/systemd/resolved.conf /etc/systemd/resolved.conf.`date "+%Y%m%d_%H%M%S"`.bak


# 確認
ls -l /etc/systemd/ | grep resolved.conf
-----------------------------------
[root@ip-172-31-38-31 ~]# ls -l /etc/systemd/ | grep resolved.conf
-rw-r--r--.  1 root root  1398 Dec 22 22:24 resolved.conf
-rw-r--r--.  1 root root  1398 Dec 22 22:24 resolved.conf.20260123_030718.bak
[root@ip-172-31-38-31 ~]#
-----------------------------------


# DNSサーバの向き先を自分のプライベートIPに変更
vi /etc/systemd/resolved.conf
----------------------------------------
#DNS=
↓
DNS= 172.31.38.31
----------------------------------------


# resolved.conf の設定を反映
systemctl restart systemd-resolved.service


# 接続確認
dig mail.kurosawa.local

```
</br>



## 自サーバへメールの送信
```bash
# ログの有効化
dnf install rsyslog
systemctl start rsyslog
systemctl status rsyslog
※ AmazonLinux2023ではデフォルトでログの書き込みが有効になっていないため。


# 自分サーバにメール送信
mail -s TestMail root@kurosawa.local
# Enter押下後、メール内容を記述
# ピリオドを入力後、Enter押下
----------------------------------------
Hello
----------------------------------------


# メールログを確認し、送信したメールの status が sent になっているかを確認
less /var/log/maillog
----------------------------------------
Jan 23 04:59:15 ip-172-31-38-31 postfix/qmgr[28277]: 90AE513D989: from=<root@mail.kurosawa.local>, size=444, nrcpt=1 (queue active)
Jan 23 04:59:15 ip-172-31-38-31 postfix/local[33510]: 90AE513D989: to=<root@kurosawa.local>, relay=local, delay=0.02, delays=0.02/0.01/0/0, dsn=2.0.0, status=sent (delivered to maildir)
Jan 23 04:59:15 ip-172-31-38-31 postfix/qmgr[28277]: 90AE513D989: removed
----------------------------------------


# メールが受信できているかを確認
mail
----------------------------------------
[root@ip-172-31-38-31 ~]# mail
Heirloom Mail version 12.5 7/5/10.  Type ? for help.
"/var/spool/mail/root": 1 message 1 new
>N  1 root                  Fri Jan 23 04:59  17/541   "TestMail"
& 1
Message  1:
From root@mail.kurosawa.local Fri Jan 23 04:59:15 2026
Return-Path: <root@mail.kurosawa.local>
X-Original-To: root@kurosawa.local
Delivered-To: root@kurosawa.local
Date: Fri, 23 Jan 2026 04:59:15 +0000
To: root@kurosawa.local
Subject: TestMail
User-Agent: Heirloom mailx 12.5 7/5/10
Content-Type: text/plain; charset=us-ascii
From: root <root@mail.kurosawa.local>
Status: R

Hello

&
----------------------------------------

```
</br>




## 他サーバへメール送信
```bash
# DNSサーバの向き先を自分のプライベートIPに変更
vi /etc/systemd/resolved.conf
----------------------------------------
#DNS= 172.31.38.31
DNS= 172.31.23.19
----------------------------------------


# resolved.conf の設定を反映
systemctl restart systemd-resolved.service


# 相手にメール送信
mail -s TestMail root@onishi.local

less /var/log/maillog

mail

```
</br>




## メールアドレス
```bash
# OSユーザ作成
useradd kurosawa -g mail -M -K MAIL_DIR=/dev/null -s /sbin/nologin
----------------------------------------
-g mailグループへ所属。 
-M ホームディレクトリを作成しない
-K 
----------------------------------------


# パスワード設定
passwd kurosawa
----------------------------------------
New password: kurosawa
Retype new password: kurosawa
----------------------------------------


# DNSサーバの向き先を自分のプライベートIPに変更
vi /etc/systemd/resolved.conf
----------------------------------------
#DNS= 172.31.38.31
DNS= 172.31.23.19
----------------------------------------


# resolved.conf の設定を反映
systemctl restart systemd-resolved.service


# ユーザ「kurosawa」にメール送信
mail -s 1111111122222222 kurosawa@kurosawa.local


# メール送信ログ確認
less /var/log/maillog


# メールファイル検索
ls -l /var/spool/mail/kurosawa/new/
----------------------------------------
[root@ip-172-31-38-31 ~]# ls -l /var/spool/mail/kurosawa/new/
total 4
-rw-------. 1 kurosawa mail 565 Jan 23 06:25 1769149511.V10301I83ec3dM526592.ip-172-31-38-31.us-west-2.compute.internal
[root@ip-172-31-38-31 ~]#
----------------------------------------


# メール確認
view /var/spool/mail/kurosawa/new/1769149511.V10301I83ec3dM526592.ip-172-31-38-31.us-west-2.compute.internal

```
</br>
</br>
</br>
</br>



# 2. Dovecot を構築する
## Dovecot のインストール
```bash
# インストール
dnf install dovecot
```
</br>




## Dovecot の設定
```bash
# dovecot.conf を変更
cp -a /etc/dovecot/dovecot.conf /etc/dovecot/dovecot.conf.`date "+%Y%m%d_%H%M%S"`.bak
ls -l /etc/dovecot/ | grep dovecot
vi /etc/dovecot/dovecot.conf
----------------------------------------
protocols = pop3

mail_location = maildir:/var/spool/mail/%u/
----------------------------------------


# 10-ssl.conf を修正
cp -a /etc/dovecot/conf.d/10-ssl.conf /etc/dovecot/conf.d/10-ssl.conf.`date "+%Y%m%d_%H%M%S"`.bak
ls -l /etc/dovecot/conf.d/ | grep 10-ssl
vi /etc/dovecot/conf.d/10-ssl.conf
----------------------------------------
sslをコメントアウト
ssl = required
↓
# ssl = required
----------------------------------------


# 10-auth.conf を修正
cp -a /etc/dovecot/conf.d/10-auth.conf /etc/dovecot/conf.d/10-auth.conf.`date "+%Y%m%d_%H%M%S"`.bak
ls -l /etc/dovecot/conf.d/ | grep 10-auth
vi /etc/dovecot/conf.d/10-auth.conf
----------------------------------------
disable_plaintext_auth を no に
#disable_plaintext_auth = yes
↓
disable_plaintext_auth = no
----------------------------------------


# dovecot 再起動
systemctl start dovecot
systemctl enable dovecot


# telnet のインストール（telnetでメールを確認する方法）
dnf install telnet


# ログイン
telnet localhost 110
----------------------------------------
# ユーザを入力
user kurosawa
+OK

# パスワードを入力
pass kurosawa
+OK Logged in.

# メールのリスト
list
+OK 1 messages:
1 581
.

# メールIDを指定して、開く
retr 1
+OK 581 octets
Return-Path: <root@mail.kurosawa.local>
X-Original-To: kurosawa@kurosawa.local
Delivered-To: kurosawa@kurosawa.local
Received: by mail.kurosawa.local (Postfix, from userid 0)
	id 7D3A2137B9D; Fri, 23 Jan 2026 06:25:11 +0000 (UTC)
Date: Fri, 23 Jan 2026 06:25:11 +0000
To: kurosawa@kurosawa.local
Subject: 1111111122222222
User-Agent: Heirloom mailx 12.5 7/5/10
MIME-Version: 1.0
Content-Type: text/plain; charset=us-ascii
Content-Transfer-Encoding: 7bit
Message-Id: <20260123062511.7D3A2137B9D@mail.kurosawa.local>
From: root <root@mail.kurosawa.local>

ggggggggff
.
----------------------------------------

```
</br>
</br>
</br>


# 演習
## ドメインを作成する
```bash
# named.conf にゾーン情報を定義
cp -a /etc/named.conf /etc/named.conf.`date "+%Y%m%d_%H%M%S"`.bak
ls -l /etc/ | grep named
vi /etc/named.conf

# 以下を追記
-----------------------------------
zone "kurosawamasaya.local" IN {
    type master;
    file "/var/named/kurosawamasaya.local.zone";
};
-----------------------------------


# named.conf の構文チェック
named-checkconf


# ゾーンファイルの作成
vi /var/named/kurosawamasaya.local.zone
----------------------------------------
$TTL 3600
@ IN SOA ns.kurosawamasaya.local. test.gmail.com. (
20220401 ; serial
3600 ; refresh
3600 ; retry
3600 ; expire
3600 ) ; minimum

        IN NS ns.kurosawamasaya.local.
        IN MX 10 mail.kurosawamasaya.local.
ns      IN A  172.31.38.31
mail     IN A  172.31.38.31
----------------------------------------


# ゾーンファイルの構文チェック
named-checkzone kurosawamasaya.local /var/named/kurosawamasaya.local.zone


# 再起動
systemctl restart named


# 状態確認
systemctl status named | less


# 接続確認
dig @localhost mail.kurosawamasaya.local


# 接続確認
dig mail.kurosawamasaya.local

```
</br>




### ペアとメール送受信
```bash
# DNSサーバの向き先を相手のプライベートIPに変更
vi /etc/systemd/resolved.conf


# resolved.conf の設定を反映
systemctl restart systemd-resolved.service

dig mail.onishi-yoshie.local


# 相手にメール送信
mail -s "hello yoshie!!!!" yoshie@onishi-yoshie.local

view /var/log/maillog

ls -l /var/spool/mail/kurosawa/new



```
</br>



telnet localhost 110






$TTL 3600
@ IN SOA ns.kurosawa.local. test.gmail.com. (
20220402 ; serial ★変更必須
3600
3600
3600
3600 )

        IN NS ns.teamc.entrycl.net.

        IN MX 10 mail1.teamc.entrycl.net.
        IN MX 10 mail2.teamc.entrycl.net.
        IN MX 10 mail3.teamc.entrycl.net.
        IN MX 10 mail4.teamc.entrycl.net.

ns      IN A 172.31.38.31

mail1   IN A 172.31.38.31
mail2   IN A 172.31.38.32
mail3   IN A 172.31.38.33
mail4   IN A 172.31.38.34

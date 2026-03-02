## ■ 1. 事前確認
### ポート53が使用されていないかを確認
```bash
sudo ss -tulnp | grep :53
```

### セキュリティグループを確認
- 外部DNSの場合：
    - DNS(UDP) 53 : 0.0.0.0/0
    - DNS(TCP) 53 : VPC CIDR
    - SSH 22 : マイIP

- 内部DNSの場合：
    - DNS(UDP) 53 VPC CIDR
    - DNS(TCP) 53 VPC CIDR
    - SSH 22 : マイIP
---
</br>


## ■ 2. 必要パッケージインストール
```bash
sudo dnf groupinstall -y "Development Tools"
sudo dnf install -y openssl-devel libevent-devel zlib-devel
```
---
</br>


## ■ 3. NSDダウンロード
最新版を取得：
```bash
LATEST=$(curl -s https://www.nlnetlabs.nl/downloads/nsd/ | grep -oP "nsd-4\.\d+\.\d+\.tar\.gz" | sort -V | tail -1)
```

確認：
```bash
echo "$LATEST"
```

▼ 確認結果
```bash
# バージョンが出ればOK
[ec2-user@ip-172-31-41-5 ~]$ echo "$LATEST"
nsd-4.14.1.tar.gz
[ec2-user@ip-172-31-41-5 ~]$
```

ダウンロード：
```bash
wget https://www.nlnetlabs.nl/downloads/nsd/$LATEST
```

解凍：
```bash
tar xvf $LATEST
```

ディレクトリ移動：
```bash
DIR_NAME=${LATEST%.tar.gz}

echo "$DIR_NAME"

cd $DIR_NAME
```
---
</br>


## ■ 4. configure
NSDのインストール場所を決定
```bash
./configure --prefix=/usr/local/nsd --disable-dnstap
```
エラーが出なければOK。

---
</br>


## ■ 5. make & install
ソースをコンパイルする（ビルドともいう）
```bash
make
```
ビルドしたファイルをOSの指定場所にコピーする
```bash
sudo make install
```
---
</br>


## ■ 6. ユーザ作成
```bash
sudo useradd -r -s /sbin/nologin nsd
```
---
</br>


## ■ 7. ディレクトリ作成
```bash
sudo mkdir -p /usr/local/nsd/etc
sudo mkdir -p /usr/local/nsd/zones
sudo chown -R nsd:nsd /usr/local/nsd
```
---
</br>


## ■ 8. 設定ファイル作成
```bash
sudo vi /usr/local/nsd/etc/nsd.conf
```
最小構成：
```conf
server:
    ip-address: 0.0.0.0
    port: 53
    username: nsd
    hide-version: yes

# ゾーン定義は、移行元を踏襲して作成すること
zone:
    name: example.com
    zonefile: /usr/local/nsd/zones/example.com.zone
```
---
</br>


## ■ 9. ゾーンファイル作成
ゾーン定義は、移行元を踏襲して作成すること。
```bash
sudo vi /usr/local/nsd/zones/example.com.zone
```
```ini
$TTL 86400
@   IN  SOA ns1.example.com. admin.example.com. (
        2026022601
        3600
        1800
        604800
        86400 )

    IN  NS  ns1.example.com.

ns1 IN  A   172.31.41.5
www IN  A   172.31.41.5
```
---
</br>


## ■ 10. 設定チェック
```bash
sudo /usr/local/nsd/sbin/nsd-checkconf /usr/local/nsd/etc/nsd.conf
```
```bash
sudo /usr/local/nsd/sbin/nsd-checkzone example.com \
/usr/local/nsd/zones/example.com.zone
```
---
</br>


## ■ 11. systemd登録
systemctlを使えるようにする。
```bash
sudo vi /etc/systemd/system/nsd.service
```

`/etc/systemd/system/nsd.service`
```bash
[Unit]
Description=NSD Authoritative DNS Server
After=network.target

[Service]
ExecStart=/usr/local/nsd/sbin/nsd -c /usr/local/nsd/etc/nsd.conf
Type=forking

[Install]
WantedBy=multi-user.target
```
有効化：
```bash
sudo systemctl daemon-reload
sudo systemctl enable nsd
sudo systemctl start nsd
```
確認(ポート53)：
```bash
sudo ss -tulnp | grep ':53'
```
▼ 想定
```
[ec2-user@ip-172-31-41-5 ~]$ sudo ss -tulnp | grep ':53'
udp   UNCONN 0      0                              0.0.0.0:53        0.0.0.0:*    users:(("nsd: server 1",pid=39618,fd=4),("nsd: main",pid=39617,fd=4),("nsd: xfrd",pid=39616,fd=4))
tcp   LISTEN 0      4096                           0.0.0.0:53        0.0.0.0:*    users:(("nsd: server 1",pid=39618,fd=5),("nsd: main",pid=39617,fd=5),("nsd: xfrd",pid=39616,fd=5))
[ec2-user@ip-172-31-41-5 ~]$
```
---
</br>


## 12. 自分自身の名前解決設定
1. 現在の状態確認
    ```bash
    ls -l /etc/resolv.conf
    ```
    もしこうなっていれば：
    ```bash
    /etc/resolv.conf -> /run/systemd/resolve/resolv.conf
    ```
    → systemd-resolved管理です。

</br>

2. resolved.conf を編集
    ```bash
    sudo vi /etc/systemd/resolved.conf
    ```
    以下を設定：
    ```
    [Resolve]
    DNS=127.0.0.1
    FallbackDNS=
    DNSStubListener=yes
    ```
    ポイント：

    - DNS=127.0.0.1 → NSDを参照
    - FallbackDNS= 空にする → 外部DNSに逃げない
    - StubListener=yes → 127.0.0.53 を有効
</br>

3. systemd-resolved 再起動
    ```bash
    sudo systemctl restart systemd-resolved
    ```
</br>

4. 確認
    ```
    resolvectl status
    ```
    DNS Server が：
    ```
    DNS Servers: 127.0.0.1
    ```
    になっていればOK。
---
</br>


## ■ 13. 動作確認
```bash
dig @<EC2のIPアドレス> www.example.com
dig @127.0.0.1 www.example.com
dig www.example.com
```
---
</br>


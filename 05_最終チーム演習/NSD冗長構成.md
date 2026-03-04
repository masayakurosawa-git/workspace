## ■ 1. 事前確認
セキュリティグループ
### 外部DNS SG
- DNS(UDP) 53 : 0.0.0.0/0
- DNS(TCP) 53 : 0.0.0.0/0
- DNS(TCP) 53 : 相手DNSのSG
- DNS(UDP) 53 : 相手DNSのSG

### 内部DNS SG
- DNS(UDP) 53 : VPC CIDR
- DNS(TCP) 53 : VPC CIDR
- DNS(TCP) 53 : 相手DNSのSG
- DNS(UDP) 53 : 相手DNSのSG
---
</br>
</br>


## ■ 2. 両方のサーバにNSDをインストール

前回の ソースビルド手順をns1/ns2両方で実施してください（`/usr/local/nsd` 配下に入る想定）。

---
</br>


## ■ 3. TSIG鍵を作る（ゾーン転送用）
ns1（Primary）で作成し、ns2にも同じ値を設定する。
```bash
openssl rand -base64 32
```
出力例：
```
BASE64_STRING
```
※ この文字列は ns1 / ns2 の両方に同じ値を設定すること。

※ 出てきた文字列を控えておきます（例：BASE64_STRING）。

---
</br>


## ■ 4. ns1（Primary）の nsd.conf を設定
ns1 と ns2 の secret は完全一致であること。
</br>
1文字でも違うとゾーン転送は失敗する。

```bash
sudo vi /usr/local/nsd/etc/nsd.conf
```
▼ 変更後
`/usr/local/nsd/etc/nsd.conf`
```bash
server:
  ip-address: 0.0.0.0
  port: 53
  username: nsd
  hide-version: yes

# ---- TSIG key (ゾーン転送/notify の認証に使う) ----
key:
  name: "xfrkey"
  algorithm: hmac-sha256
  secret: "BASE64_STRING"

zone:
  name: example.com
  zonefile: /usr/local/nsd/zones/example.com.zone

  # SecondaryへNOTIFY（更新通知）
  notify: 172.31.21.52 xfrkey

  # ゾーン転送を許可（Secondaryのみ）
  provide-xfr: 172.31.21.52 xfrkey
```
---
</br>


## ■ 5. ns2（Secondary）の nsd.conf を設定
```bash
sudo vi /usr/local/nsd/etc/nsd.conf
```
▼ 変更後
`/usr/local/nsd/etc/nsd.conf`
```bash
server:
  ip-address: 0.0.0.0
  port: 53
  username: nsd
  hide-version: yes

key:
  name: "xfrkey"
  algorithm: hmac-sha256
  secret: "BASE64_STRING"

zone:
  name: example.com
  # Secondary側の受信ゾーン保存先
  zonefile: /usr/local/nsd/zones/example.com.zone

  # Primaryからゾーン転送を要求
  request-xfr: 172.31.20.41@53 xfrkey

  # PrimaryからのNOTIFYを受ける
  allow-notify: 172.31.20.41 xfrkey
```
ns2は、空のゾーンファイルを作成：
```bash
sudo touch /usr/local/nsd/zones/example.com.zone
sudo chown nsd:nsd /usr/local/nsd/zones/example.com.zone
```
※ 空のゾーンファイルを作成しないと、ゾーンを authoritative としてロードしない

※ そのため、ns2(Secondary)に空ファイルを作成する。

---
</br>


## ■ 6. ns1（Primary）のゾーンファイルに NS レコードを2台分書く
ns1の `/usr/local/nsd/zones/example.com.zone`（例）
```bash
sudo vi /usr/local/nsd/zones/example.com.zone
```
▼ 変更後
```bash
$TTL 86400
@ IN SOA ns1.example.com. admin.example.com. (
  2026022701 ; serial ←更新時に必ず増やす
  3600
  1800
  604800
  86400
)

@   IN NS ns1.example.com.
@   IN NS ns2.example.com.

ns1 IN A 172.31.20.41
ns2 IN A 172.31.21.52

www IN A 172.31.20.80
```
---
</br>


## ■ 7. 起動順（重要）
1. ns1（Primary）起動
2. ns2（Secondary）起動（ns1からゾーン転送してくる）

### ns1
```bash
sudo /usr/local/nsd/sbin/nsd-checkconf /usr/local/nsd/etc/nsd.conf
sudo /usr/local/nsd/sbin/nsd-checkzone example.com /usr/local/nsd/zones/example.com.zone
sudo systemctl restart nsd
```
### ns2
```bash
sudo /usr/local/nsd/sbin/nsd-checkconf /usr/local/nsd/etc/nsd.conf
sudo systemctl restart nsd
```
---
</br>


## ■ 8. 動作確認
### ① ns1が返せる
```bash
dig @172.31.20.41 example.com SOA +norec
```
### ② ns2が返せる（＝転送成功）
```bash
dig @172.31.21.52 example.com SOA +norec
```
確認ポイント：

ns1 と ns2 の SOA serial が一致していること。

### ③ ns2がゾーンファイルを受け取ったか確認
```bash
sudo ls -l /usr/local/nsd/zones/
sudo grep SOA -n /usr/local/nsd/zones/example.com.zone
```
---
</br>


## 更新運用の流れ（ここが本番の肝）

1. ns1のゾーンファイルを編集

2. serial を必ず増やす

3. reload（ns1）

4. ns1がNOTIFY → ns2が取り直す

ns1で：
```bash
sudo systemctl reload nsd
```
---
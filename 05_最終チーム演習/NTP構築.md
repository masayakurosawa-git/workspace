# NTP設定(サーバ側)
### バックアップ作成
```bash
sudo cp -a /etc/chrony.conf /etc/chrony.conf.bak_$(date +%Y%m%d_%H%M%S)
```

### 設定追加
```bash
sudo vi /etc/chrony.conf
```
▼ 外部参照をすべて削除し、以下だけ残す
```bash
# pool 2.amazon.pool.ntp.org iburst

local stratum 10
allow 10.0.0.0/16
```

### サービス起動
```bash
sudo systemctl enable chronyd
sudo systemctl start chronyd
```

### 確認
```bash
chronyc tracking
```
▼ 実行結果
```
Reference ID : 7F7F0101 (LOCAL)
```

### セキュリティグループ設定
```bash
# DBサーバのSGに以下を追加：
Type: MYSQL/Aurora
Port: 123
Protocol: UDP
Source: 10.0.0.0/16
```
</br>
</br>


# NTP設定(クライアント側)
### バックアップ作成
```bash
sudo cp -a /etc/chrony.conf /etc/chrony.conf.bak_$(date +%Y%m%d_%H%M%S)
```

### (変更)設定追加１
```bash
sudo vi /etc/chrony.conf
```
▼ 以下に変更
```bash
sourcedir /run/chrony.d
↓
# sourcedir /run/chrony.d
```

### (新規作成)設定追加２
```bash
sudo vi /etc/chrony.d/internal-ntp.sources
```
▼ 以下に変更
```bash
# NTPサーバのIPアドレス
server 10.0.0.164 iburst
```

### サービス起動
```bash
sudo systemctl enable chronyd
sudo systemctl restart chronyd
```

### 確認
```bash
chronyc sources -v
```
▼ 内容
```
^* 10.0.0.164
```

### タイムゾーン確認
```bash
timedatectl
sudo timedatectl set-timezone Asia/Tokyo
```

# wp-3tier Ansible (Shell -> Ansible 移行版)

移行元のシェル一式（00_env.sh / 01_common.sh / 10_web_setup.sh / 20_ap_setup.sh / 30_db_setup.sh / 40_inner_dns_setup.sh / 99_run_all.sh）
を Ansible に移行し、`site.yml` 1回で **DB → AP → WEB → 内部DNS** の順に適用します。

---
</br>

## 前提
- 対象OS: Amazon Linux 2023
- 接続ユーザ: `ec2-user`（変更する場合は `group_vars/all.yml` の `ssh_user`）
- SSH鍵はローカルのssh-agentや `~/.ssh/config`、または `-e ansible_ssh_private_key_file=...` で指定してください
- 4台の EC2 が起動済みで、SSH疎通できること
- セキュリティグループは要件どおり（WEB:80/myip, 共通:22/myip, AP:9000 from WEB-SG, DB:3306 from AP-SG, DNS:53 など）
---
</br>

## 重要: 変更箇所はここだけ
環境差分の変更は **`group_vars/all.yml` だけ** を編集してください。
- IP（public/private）
- ドメイン（`domain_name_inner`）
- WordPress DB（`wp_db_name/wp_db_user/wp_db_pass`）
- MariaDB hardening の root パスワード（`mariadb_root_password`）

inventory は host/group 定義のみ（IP列挙）です。

---
</br>

## セットアップ（ローカル）
### 1) コレクション導入
```bash
ansible-galaxy collection install -r collections/requirements.yml
```
---
</br>

### 2) python依存（ローカル側）
（基本は不要ですが、環境により ansible 実行に python が必要です）
```bash
python3 -m pip install -r requirements.txt
```
※ requirements.txt は主に「ターゲット側で pip により PyMySQL を入れる」用途ですが、
ローカルの ansible 実行環境でも python/pip が必要な場合があります。

---
</br>

### 実行
```bash
ansible-playbook -i inventory/hosts.ini site.yml
```
---
</br>

### トラブルシュート（ログ確認タスクも実行したい）
```bash
ansible-playbook -i inventory/hosts.ini site.yml --tags troubleshoot
```
---
</br>

### ログ
- Ansible 実行ログは logs/ansible.log に保存されます（ansible.cfg の log_path）。
- 失敗時はログに「どのホストの」「どのタスク名で」落ちたかが残ります。
---
</br>

### 何をするか（概要）
#### common ロール
- dnf upgrade（`common_dnf_upgrade: true` の場合）
- 共通パッケージ導入（curl/tar/wget 等）
- systemd-resolved の DNS/Domain 設定（バックアップ付き・再起動）

#### db ロール
- MariaDB (mariadb105-server) 導入・起動
- mysql_secure_installation 相当の hardening（非対話・冪等）
    - rootパスワード（未設定時のみ設定を試行）
    - 匿名ユーザ削除
    - remote root禁止（root@% 削除）
    - test DB 削除
    - FLUSH PRIVILEGES
- WordPress 用 DB/ユーザ作成（ユーザ host は ap_private_ip）

#### ap ロール
- php-fpm と関連パッケージ導入
- `/etc/php-fpm.d/www.conf` をバックアップして設定変更
    - user/group=apache
    - listen=9000
    - listen.allowed_clients=WEB_PRIVATE_IP
- WordPress を /var/www/html に配置し wp-config.php 反映
- SELinux boolean: httpd_can_network_connect=on

#### web ロール
- httpd 導入・起動
- /etc/httpd/conf.d/php-fpm.conf を template で作成（APへ fcgi転送）
- DirectoryIndex を index.php優先に変更（バックアップ付き）
- WordPress を /var/www/html に配置し wp-config.php 反映
- SELinux boolean: httpd_can_network_connect=on

#### inner_dns ロール
- bind/named 導入・起動
- /var/named/<domain>.zone を template で作成（ns/ap/web/db の A レコード）
- /etc/named.conf をバックアップしつつ冪等に反映
- listen-on / listen-on-v6 をコメントアウト（127.0.0.1 / ::1）
- allow-query any
- zone 定義ブロック追加（blockinfile）
- named-checkconf 実行（不整合なら fail）
---
</br>

### よくある失敗と切り分け
- DB接続できない:
    - `sub_domain_db` の名前解決が inner_dns を参照しているか（commonロールの resolver 設定）
    - DBのユーザhostが `ap_private_ip` になっているか
    - SG/NACLで 3306 が AP → DB に通っているか

- 名前解決が効かない:
    - `--tags troubleshoot` で resolvectl status / named-checkzone / journalctl を確認

- httpd→php-fpm疎通できない:
    - AP側 php-fpm が 9000 LISTEN しているか
    - allowed_clients が web_private_ip になっているか
    - SGで 9000 が WEB-SG から許可されているか
---
</br>
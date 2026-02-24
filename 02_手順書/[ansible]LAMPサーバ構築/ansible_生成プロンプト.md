## コード生成用プロンプト
```
あなたは経験豊富なインフラエンジニア兼Ansible設計者です。
以下の要件で、既存のシェルスクリプト一式をAnsibleへ移行してください。
成果物は「そのままリポジトリに配置して実行できる」品質で出力してください。

# 1. 背景（移行元）
移行元のシェルは以下の構成です。
- 00_env.sh: IP/ドメイン/DB情報などパラメータ定義（例: WEB_PUBLIC_IP, WEB_PRIVATE_IP, WP_DB_NAME, DOMAIN_NAME_INNER など）
- 01_common.sh: ログ、共通関数、systemd-resolvedのDNS設定など（run_with_spinner と LOG_FILE 出力あり）
- 10_web_setup.sh: WEB（httpd, proxy_fcgi php-fpm転送設定, WordPress配置, DirectoryIndex, DNS向き先設定）
- 20_ap_setup.sh: AP（php-fpm設定 listen=9000, allowed_clients=WEB_PRIVATE_IP, WordPress配置, DNS向き先設定）
- 30_db_setup.sh: DB（mariadb install/start, DB/ユーザ作成。元はmysql_secure_installation対話想定）
- 40_inner_dns_setup.sh: 内部DNS（bind/named, zone作成, named.conf修正, DNS向き先設定）
- 99_run_all.sh: ローカルから順序実行（DB→AP→WEB→内部DNS）し、scp/sshで配布して実行

# 2. 実現したいこと
上記をAnsibleに移行し、main.yml 1回で全サーバに順番に適用したい。

# 3. 絶対要件
(1) ロール分割
- roles/web
- roles/ap
- roles/db
- roles/inner_dns
- roles/common（共通処理を集約：dnf upgrade、DNS resolver設定、共通パッケージ等）
のように、WEB/AP/DB/内部DNSサーバでロールを分けること。

(2) パラメータは1箇所を修正すれば運用できること
- 変数は group_vars/all.yml（または vars/main.yml など “1ファイル”）に集約。
- inventory には host/group の定義だけを書く。
- 00_env.sh相当の値（Public/Private IP、DOMAIN_NAME_INNER、SUB_DOMAIN_WEB/AP/DB、WP_DB_NAME/USER/PASS 等）はAnsible変数に置き換える。
- 変数の例は 00_env.sh の内容を踏襲すること。

(3) DB構築で mysql_secure_installation と同等の処理を自動実行できること（非対話）
- Ansibleで idempotent（複数回実行しても壊れない）にすること。
- 最低限、以下を実現：
  a) rootパスワード設定（未設定時のみ）
  b) 匿名ユーザー削除
  c) remote root ログイン禁止（必要なら localhost に限定）
  d) test DB 削除
  e) 権限テーブル再読み込み
- 可能なら community.mysql を利用。使う場合は必要コレクションとpip要件も明示。
- MariaDBは Amazon Linux 2023 で mariadb105-server 相当でOK。

(4) main.yml 実行で順番に実行
- 実行順は 99_run_all.sh と同じ：DB → AP → WEB → 内部DNS
- Ansibleの複数Playで順序を担保し、各Playで対象groupを限定すること。
- 例：- hosts: db → - hosts: ap → - hosts: web → - hosts: inner_dns の順。

# 4. 追加要件（今回追加）
(5) シェル内のスピナー関数は使用しなくても問題ない
- run_with_spinner 相当の UI 表示（進捗スピナー）はAnsibleでは不要。置き換えない/実装しないでOK。
- 代わりに、Ansibleの標準出力とログで状況が追えるようにすること。

(6) エラー原因などがわかるログ出力を実装すること
- 実行ログをファイルに保存できるようにする（例：ansible-playbook 実行時のログ）。
- Ansible側の設定として以下を必ず用意：
  - ansible.cfg を同梱し、log_path を repo直下の logs/ansible.log などへ出力
  - stdout_callback を yaml 等にして見やすくする（利用可能な範囲で）
  - hostごとの実行結果が追えるようにし、失敗時にどのタスクで落ちたか分かる形にする
- 各ロールの重要工程では、fail時に原因が分かるようにする（例：command の戻り値/標準エラーを register して失敗メッセージに含める、assert を使う等）
- 設定ファイル変更は backup を必ず取り、いつ・何を変えたかがログで追えるようにする
- 追加で、必要なら /var/log/（httpd, php-fpm, mariadb, named等）の確認タスク（debug用）を「トラブルシュート用タグ」などで実装してよい（通常実行では動かさない）

# 5. 仕様（移行内容の期待）
- WEB:
  - httpd install/enable/start
  - /etc/httpd/conf.d/php-fpm.conf を作成し FilesMatchで proxy:fcgi://<SUB_DOMAIN_AP>:9000 に転送
  - SELinux boolean httpd_can_network_connect=on
  - WordPress を /var/www/html に配置し、wp-config.phpに DB_NAME/USER/PASS/HOST を反映（DB_HOSTはSUB_DOMAIN_DB）
  - DirectoryIndex を index.php index.html にする
  - DNS resolver は inner dns を参照（systemd-resolved設定）

- AP:
  - php-fpm と関連パッケージ install/enable/start
  - /etc/php-fpm.d/www.conf をバックアップして user/group=apache, listen=9000, listen.allowed_clients=WEB_PRIVATE_IP
  - SELinux boolean httpd_can_network_connect=on
  - WordPress を /var/www/html に配置し、wp-config.phpはWEBと同一内容（DB_HOSTはSUB_DOMAIN_DB）
  - DNS resolver は inner dns を参照

- DB:
  - MariaDB install/enable/start
  - mysql_secure_installation相当のhardening（上記要件(3)）
  - WP用DB/ユーザ作成（ユーザのhostはAP_PRIVATE_IPを想定、権限付与、FLUSH）
  - DNS resolver は inner dns を参照

- inner_dns:
  - bind/named install/enable/start
  - zoneファイル /var/named/<DOMAIN_NAME_INNER>.zone を作成
    - ns/ap/web/db のAレコードは 00_env.sh の private IP 変数に対応させる
  - /etc/named.conf をバックアップして listen-on/allow-query/zone追加 などを idempotent に反映
  - named-checkconf 実行
  - DNS resolver は localhost を参照（systemd-resolved設定）

# 6. 成果物として出力してほしいもの（ファイル構成まで）
- inventory/hosts.ini（groups: web, ap, db, inner_dns）
- group_vars/all.yml（唯一のパラメータ集約ファイル）
- site.yml（= main.yml。順番Playで構成）
- ansible.cfg（log_pathなどログ設定を含む。logs/ディレクトリ運用前提）
- roles/common/tasks/main.yml（dnf update、resolver設定など共通化）
- roles/<role>/tasks/main.yml（各ロールの実処理）
- roles/<role>/handlers/main.yml（サービスrestart等が必要なら）
- roles/<role>/templates/（wp-config.php, php-fpm.conf, zoneファイル等は可能な限りtemplate化）
- README.md（実行手順、事前条件、必要コレクション、pip、想定OS、実行例、ログの見方、失敗時の切り分け）

# 7. 重要な実装ルール
- すべて冪等（idempotent）であること。shellのコピー実行ではなく、可能な限りAnsibleモジュールで書く。
- バックアップを取る（元シェルがやっている設定変更は backup: yes 相当を入れる）。
- 変数は group_vars/all.yml 以外に分散させない（defaults等に分けない）。
- どこを変更すれば環境が変えられるか（＝group_vars/all.ymlだけ）をREADMEに明記。
- ログを見れば「どのホストの」「どのタスクで」「何が原因で」失敗したか追えること。

# 8. 入力値（00_env.sh相当の例）
次の変数キーを必ず用意し、group_vars/all.ymlに置くこと：
- ssh_user（例: ec2-user）
- web_public_ip, ap_public_ip, db_public_ip, inner_dns_public_ip
- web_private_ip, ap_private_ip, db_private_ip, inner_dns_private_ip
- local_host（127.0.0.1）
- wp_db_name, wp_db_user, wp_db_pass
- domain_name_inner（例: wp.local）
- sub_domain_web, sub_domain_ap, sub_domain_db
※ sub_domain_xxx は domain_name_inner から組み立ててもよい（例: "ap.{{ domain_name_inner }}"）

# 9. 出力形式
- まずファイルツリーを提示
- 次に各ファイルを「ファイル名 → コードブロック」で順にすべて出力
- 省略禁止（全部出す）
- コマンド例：ansible-playbook -i inventory/hosts.ini site.yml をREADMEに含める

以上でAnsible一式を生成してください。
```
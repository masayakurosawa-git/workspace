## ファイル構成
```
[kurosawamasaya@kurosawamasayanoMacBook-Pro ansible (main *)]$ cd "$BASE" && tree
.
├── ansible.cfg
├── collections
│   └── requirements.yml
├── group_vars
│   └── all.yml
├── inventory
│   └── hosts.ini
├── logs
├── README.md
├── requirements.txt
├── roles
│   ├── ap
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── tasks
│   │   │   └── main.yml
│   │   └── templates
│   │       └── wp-config.php.j2
│   ├── common
│   │   ├── handlers
│   │   │   └── main.yml
│   │   └── tasks
│   │       └── main.yml
│   ├── db
│   │   ├── handlers
│   │   │   └── main.yml
│   │   └── tasks
│   │       └── main.yml
│   ├── inner_dns
│   │   ├── handlers
│   │   │   └── main.yml
│   │   ├── tasks
│   │   │   └── main.yml
│   │   └── templates
│   │       └── zone.j2
│   └── web
│       ├── handlers
│       │   └── main.yml
│       ├── tasks
│       │   └── main.yml
│       └── templates
│           ├── php-fpm.conf.j2
│           └── wp-config.php.j2
└── site.yml

24 directories, 21 files
[kurosawamasaya@kurosawamasayanoMacBook-Pro ansible (main *)]$ 
```
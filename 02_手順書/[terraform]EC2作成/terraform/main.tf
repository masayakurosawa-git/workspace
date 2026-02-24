#######################################
# Provider / Data
#######################################
provider "aws" {
  region = var.aws_region
}

data "aws_vpc" "default" {
  default = true
}

# Amazon Linux 2023 (x86_64) の最新AMIを取得（固定AMI禁止）
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

#######################################
# Security Groups
#######################################
# 共通: SSH(22)は自分のIP(var.my_ip_cidr)のみ許可 / outbound all allow

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "SG for WEB"
  vpc_id      = data.aws_vpc.default.id

  # SSH (共通)
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # HTTP 80 (WEBのみ / MyIP限定)
  ingress {
    description = "HTTP from my IP only"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web-sg"
    Project = var.project_name
    Role    = "web"
  }
}

resource "aws_security_group" "ap" {
  name        = "${var.project_name}-ap-sg"
  description = "SG for AP"
  vpc_id      = data.aws_vpc.default.id

  # SSH (共通)
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # TCP 9000 (WEB SG からのみ)
  ingress {
    description              = "TCP 9000 from WEB SG only"
    from_port                = 9000
    to_port                  = 9000
    protocol                 = "tcp"
    security_groups          = [aws_security_group.web.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-ap-sg"
    Project = var.project_name
    Role    = "ap"
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "SG for DB"
  vpc_id      = data.aws_vpc.default.id

  # SSH (共通)
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # MySQL 3306 (AP SG からのみ)
  ingress {
    description     = "MySQL 3306 from AP SG only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ap.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-db-sg"
    Project = var.project_name
    Role    = "db"
  }
}

resource "aws_security_group" "inner_dns" {
  name        = "${var.project_name}-inner-dns-sg"
  description = "SG for INNER_DNS"
  vpc_id      = data.aws_vpc.default.id

  # SSH (共通)
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
  }

  # DNS 53/udp は 0.0.0.0/0 許可
  ingress {
    description = "DNS UDP 53 from anywhere"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS 53/tcp は 自分のネットワークCIDRのみ許可
  ingress {
    description = "DNS TCP 53 from my network only"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = [var.my_network_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-inner-dns-sg"
    Project = var.project_name
    Role    = "inner-dns"
  }
}

#######################################
# EC2 Instances (4台)
# - 既定VPC/既定サブネットに任せるため subnet_id は指定しない
# - 公開IPは associate_public_ip_address=true を指定
#######################################
locals {
  common_tags = {
    Project = var.project_name
  }
}

resource "aws_instance" "web" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web"
    Role = "web"
  })
}

resource "aws_instance" "ap" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.ap.id]
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ap"
    Role = "ap"
  })
}

resource "aws_instance" "db" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.db.id]
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-db"
    Role = "db"
  })
}

resource "aws_instance" "inner_dns" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.ssh_key_name
  vpc_security_group_ids      = [aws_security_group.inner_dns.id]
  associate_public_ip_address = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-inner-dns"
    Role = "inner-dns"
  })
}

#######################################
# Post Apply: update_env.sh → (optional) 99_run_all.sh
#######################################
# 1) 00_env.sh の8変数を更新（バックアップ作成）
resource "null_resource" "update_env" {
  depends_on = [
    aws_instance.web,
    aws_instance.ap,
    aws_instance.db,
    aws_instance.inner_dns
  ]

  # IPが変わったときに再実行されるようにする
  triggers = {
    web_public  = aws_instance.web.public_ip
    ap_public   = aws_instance.ap.public_ip
    db_public   = aws_instance.db.public_ip
    dns_public  = aws_instance.inner_dns.public_ip

    web_private = aws_instance.web.private_ip
    ap_private  = aws_instance.ap.private_ip
    db_private  = aws_instance.db.private_ip
    dns_private = aws_instance.inner_dns.private_ip
  }

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/bash", "-lc"]
    command     = "chmod +x ./scripts/update_env.sh && ./scripts/update_env.sh"
  }
}

# 2) var.run_after_apply=true のときだけ 99_run_all.sh を実行
resource "null_resource" "run_all" {
  count      = var.run_after_apply ? 1 : 0
  depends_on = [null_resource.update_env]

  # update_env と同条件で、IP変更時に再実行できる
  triggers = null_resource.update_env.triggers

  provisioner "local-exec" {
    working_dir = path.module
    interpreter = ["/bin/bash", "-lc"]
    command     = "chmod +x ./scripts/99_run_all.sh && ./scripts/99_run_all.sh"
  }
}

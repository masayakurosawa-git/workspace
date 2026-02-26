variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "Existing EC2 KeyPair name"
  type        = string
}

variable "my_ip_cidr" {
  type        = string
  default     = null
  description = "SSH許可するCIDR。未指定なら実行端末のグローバルIP/32を自動利用"
}

variable "my_network_cidr" {
  description = "Your network CIDR for DNS TCP 53 (e.g. home/office network)"
  type        = string
  # 例: "192.168.0.0/24"
}

variable "project_name" {
  description = "Project name prefix for resources"
  type        = string
  default     = "LAMP"
}

variable "run_after_apply" {
  description = "If true, run ./99_run_all.sh after updating 00_env.sh"
  type        = bool
  default     = false
}

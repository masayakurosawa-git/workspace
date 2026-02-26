data "http" "myip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  # var.my_ip_cidr が指定されていればそれを優先、
  # 未指定(null)なら実行端末のグローバルIP/32 を自動採用
  my_ip_cidr_effective = coalesce(var.my_ip_cidr, "${chomp(data.http.myip.response_body)}/32")
}
output "web_public_ip" {
  value = aws_instance.web.public_ip
}

output "ap_public_ip" {
  value = aws_instance.ap.public_ip
}

output "db_public_ip" {
  value = aws_instance.db.public_ip
}

output "inner_dns_public_ip" {
  value = aws_instance.inner_dns.public_ip
}

output "web_private_ip" {
  value = aws_instance.web.private_ip
}

output "ap_private_ip" {
  value = aws_instance.ap.private_ip
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

output "inner_dns_private_ip" {
  value = aws_instance.inner_dns.private_ip
}

output "public_ip" {
  value = aws_instance.monitor.public_ip
}

output "status_page_url" {
  value = "http://${aws_instance.monitor.public_ip}:8000"
}

output "grafana_url" {
  value = "http://${aws_instance.monitor.public_ip}:3000"
}

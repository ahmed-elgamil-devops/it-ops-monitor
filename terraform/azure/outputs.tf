output "public_ip" {
  value = azurerm_public_ip.pip.ip_address
}

output "status_page_url" {
  value = "http://${azurerm_public_ip.pip.ip_address}:8000"
}

output "grafana_url" {
  value = "http://${azurerm_public_ip.pip.ip_address}:3000"
}

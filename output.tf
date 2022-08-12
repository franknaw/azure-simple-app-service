
output "prod_url" {
  value = "https://${azurerm_linux_web_app.web-app-node.name}.azurewebsites.net"
}

output "slot_one_url" {
  value = "https://${azurerm_linux_web_app.web-app-node.name}-${azurerm_linux_web_app_slot.slot-1.name}.azurewebsites.net"
}

output "slot-0" {
  value = azurerm_linux_web_app.web-app-node.site_credential
  sensitive = true
}

output "slot-1" {
  value = azurerm_linux_web_app_slot.slot-1.site_config
}
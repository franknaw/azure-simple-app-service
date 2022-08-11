
output "prod_url" {
  value = "https://${azurerm_linux_web_app.web-app-node.name}.azurewebsites.net"
}

output "slot_one_url" {
  value = "https://${azurerm_linux_web_app.web-app-node.name}-${azurerm_linux_web_app_slot.slot-1.name}.azurewebsites.net"
}
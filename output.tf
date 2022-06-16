output "vmss_public_ip_fqdn" {
  value = azurerm_public_ip.publicip.fqdn
}
/*
output "jumpbox_public_ip_fqdn" {
  value = azurerm_public_ip.jumpbox-Ip.fqdn
}

output "jumpbox_public_ip" {
  value = azurerm_public_ip.jumpbox-Ip.ip_address
}
*/


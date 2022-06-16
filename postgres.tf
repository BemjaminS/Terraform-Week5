resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "ben-postgres"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  version                = "13"
  delegated_subnet_id    = azurerm_subnet.Private_Subnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.default.id
  administrator_login    = var.postgres_Username
  administrator_password = var.admin_password
  #zone                   = "1"
  storage_mb            = 32768
  sku_name              = "B_Standard_B1ms"
  backup_retention_days = 7

  depends_on = [azurerm_private_dns_zone_virtual_network_link.default]
}


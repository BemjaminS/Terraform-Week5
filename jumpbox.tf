resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "azurerm_public_ip" "jumpbox-Ip" {
 name                         = "jumpbox-public-ip"
 location                     = var.location
 resource_group_name          = azurerm_resource_group.rg.name
 allocation_method            = "Static"
 domain_name_label            = "${random_string.fqdn.result}-ssh"
  sku                         = "Standard"
}

resource "azurerm_network_interface" "jumpbox_Nic" {
 name                = "jumpbox-nic"
 location            = var.location
 resource_group_name = azurerm_resource_group.rg.name

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = azurerm_subnet.Public_Subnet.id
   private_ip_address_allocation = "Dynamic"
   public_ip_address_id          = azurerm_public_ip.jumpbox-Ip.id
 }

}

resource "azurerm_virtual_machine" "jumpbox_Vm" {
 name                  = "jumpbox"
 location              = var.location
 resource_group_name   = azurerm_resource_group.rg.name
 network_interface_ids = [azurerm_network_interface.jumpbox_Nic.id]
 vm_size               = "Standard_B1s"

    storage_image_reference {
   publisher = "Canonical"
   offer     = "0001-com-ubuntu-server-foca"
   sku       = "20_04-lts-gen2"
   version   = "latest"
 }

 storage_os_disk {
   name              = "jumpbox-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "jumpbox"
   admin_username = var.admin_username
   admin_password = var.admin_password
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

}

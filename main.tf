# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}

data "azurerm_shared_image_version" "VMimage" {
  name                = var.image_version_name
  image_name          = var.image_name
  gallery_name        = var.image_gallery_name
  resource_group_name = var.image_resource_group_name
}


#------------------------------------------------>
# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.azurerm_resource_group_name
  location = var.location
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = "Vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create private subnet
resource "azurerm_subnet" "Private_Subnet" {
  name                 = var.Private_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.Private_Subnet
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"

    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"

      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }

  }

}
#Create public subnet
resource "azurerm_subnet" "Public_Subnet" {
  name                 = var.Public_subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.Public_Subnet
}

resource "azurerm_private_dns_zone" "default" {
  name                = "Dns-pdz.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [azurerm_subnet_network_security_group_association.private]
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  name                  = "Dns-pdzvnetlink.com"
  private_dns_zone_name = azurerm_private_dns_zone.default.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
}



resource "azurerm_linux_virtual_machine_scale_set" "Vm_ScaleSet" {
  name                = "ScaleSet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_B1s"
  instances           = 3
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false

  source_image_id = data.azurerm_shared_image_version.VMimage.id


  /*source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  */

  os_disk {

    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  lifecycle {
    ignore_changes = ["instances"]
  }

  network_interface {
    name    = "NIC"
    primary = true

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.Public_Subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.backend_address_pool_public.id]
    }
  }
}

resource "azurerm_monitor_autoscale_setting" "scaling" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.Vm_ScaleSet.id

  profile {
    name = "AutoScale"

    capacity {
      default = 3
      minimum = 2
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.Vm_ScaleSet.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.Vm_ScaleSet.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}#----------------------------------------------------Public-Ip------->
# Create public IP
resource "azurerm_public_ip" "publicip" {
  name                = "PubIp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"

}

#Create Load Balancer
resource "azurerm_lb" "publicLB" {
  name                = "Public_LoadBalancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.publicip.id
  }
}
#Create rule For load balancer
resource "azurerm_lb_nat_rule" "n_rule" {
  count = 3
  resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.publicLB.id
  name                           = "SSHconnect${count.index}"
  protocol                       = "Tcp"
  frontend_port                  = "5000${count.index}"
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.publicLB.frontend_ip_configuration[0].name
}


#Create backend address pool for the lb
resource "azurerm_lb_backend_address_pool" "backend_address_pool_public" {
  loadbalancer_id = azurerm_lb.publicLB.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = azurerm_resource_group.rg.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.publicLB.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = azurerm_lb.publicLB.frontend_ip_configuration[0].name
}
#Create lb probe for port 8080
resource "azurerm_lb_probe" "lb_probe" {
  name = "tcpProbe"
  #resource_group_name = azurerm_resource_group.rg.name
  loadbalancer_id     = azurerm_lb.publicLB.id
  protocol            = "Http"
  port                = 8080
  interval_in_seconds = 5
  number_of_probes    = 2
  request_path        = "/"

}



#Create lb rule for port 8080
resource "azurerm_lb_rule" "LB_rule" {
  #resource_group_name            = azurerm_resource_group.rg.name
  loadbalancer_id                = azurerm_lb.publicLB.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = azurerm_lb.publicLB.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.lb_probe.id
  #backend_address_pool_ids       = azurerm_lb_backend_address_pool.backend_address_pool_public.id
}
#--------------------------------------------------------Security group------------------->
# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "PUBLIC_NSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name


  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.my_ip
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Port_8080"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8080"
    source_address_prefix      = azurerm_public_ip.publicip.ip_address
    destination_address_prefix = "*"
  }

}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "Dbnsg" {
  name                = "Private_NSG"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name


  security_rule {
    name                       = "PORT_5432"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5432"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

}
#---------------------------------------------------------subnet association ------->
#Associate subnet to subnet_network_security_group
resource "azurerm_subnet_network_security_group_association" "public" {
  subnet_id                 = azurerm_subnet.Public_Subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}


#Associate subnet to subnet_network_security_group
resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.Private_Subnet.id
  network_security_group_id = azurerm_network_security_group.Dbnsg.id
}


resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "azurerm_public_ip" "jumpbox" {
 name                         = "jumpbox-public-ip"
 location                     = var.location
 resource_group_name          = azurerm_resource_group.rg.name
 allocation_method            = "Static"
 domain_name_label            = "${random_string.fqdn.result}-ssh"
}

resource "azurerm_network_interface" "jumpbox" {
 name                = "jumpbox-nic"
 location            = var.location
 resource_group_name = azurerm_resource_group.rg.name

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = azurerm_subnet.Public_Subnet.id
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = azurerm_public_ip.jumpbox.id
 }

}

resource "azurerm_virtual_machine" "jumpbox" {
 name                  = "jumpbox"
 location              = var.location
 resource_group_name   = azurerm_resource_group.rg.name
 network_interface_ids = [azurerm_network_interface.jumpbox.id]
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



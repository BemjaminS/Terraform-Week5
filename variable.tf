variable "azurerm_resource_group_name" {
  description = "this is the name of resource group"
  default     = "BootCamp-Week-5"
}

variable "location" {
  default = "North Central Us"
}

variable "public_vm_size" {
  type        = string
  description = "Vm-Size Config"
  default     = "Standard_B1s"
}

variable "image_version_name" {
  default = "2.0.0"
  type    = string
}
variable "image_name" {
  default = "Image_Defintion"
  type    = string
}

variable "image_gallery_name" {
  default = "New_Image"
  type    = string
}
variable "image_resource_group_name" {
  default = "App_Image"
  type    = string
}


variable "Public_subnet_name" {
  default = "Public_subnet"
}
variable "Private_subnet_name" {
  default = "Private_subnet"
}


variable "Public_Subnet" {
  default = ["10.0.1.0/24"]
}
variable "Private_Subnet" {
  default = ["10.0.2.0/24"]
}

variable "name_prefix" {
  default     = "postgresqlfs"
  description = "Prefix of the resource name."
}


variable "admin_username" {
  default     = "ubuntu"
  type        = string
  description = "Administrator user name for virtual machine"
}
variable "postgres_Username" {
  default     = "weightTracker"
  type        = string
  description = "Username For Data-base"
}

variable "admin_password" {
  default     = "Ben11223344!"
  type        = string
  description = "Password For virtual machine"
}

variable "my_ip" {
  type        = string
  description = "ip user"
}


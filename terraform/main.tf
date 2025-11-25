terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "vm_infrastructure" {
  source = "./modules/vm"

  resource_group_name   = var.resource_group_name
  location              = var.location
  vm_name               = var.vm_name
  vm_size               = var.vm_size
  admin_username        = var.admin_username
  admin_ssh_public_key  = var.admin_ssh_public_key
  vnet_address_space    = var.vnet_address_space
  subnet_address_prefix = var.subnet_address_prefix
  admin_users           = var.admin_users
  tags                  = var.tags
}

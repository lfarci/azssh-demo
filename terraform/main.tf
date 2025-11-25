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

  backend "azurerm" {}
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
  subscription_id = var.subscription_id
}

locals {
  # Compute resource names based on location and workflow name
  location_short = {
    "eastus"      = "eus"
    "westus"      = "wus"
    "centralus"   = "cus"
    "northeurope" = "neu"
    "westeurope"  = "weu"
  }
  location_code       = lookup(local.location_short, var.location, substr(var.location, 0, 3))
  resource_group_name = "rg-${var.workflow_name}-${local.location_code}"
  vm_name             = "vm-${var.workflow_name}-${local.location_code}"
  keyvault_name       = "kv-${var.workflow_name}-${local.location_code}-${substr(md5(var.subscription_id), 0, 6)}"
}

module "vm_infrastructure" {
  source = "./modules/vm"

  subscription_id       = var.subscription_id
  resource_group_name   = local.resource_group_name
  location              = var.location
  vm_name               = local.vm_name
  vm_size               = var.vm_size
  admin_username        = var.admin_username
  admin_ssh_public_key  = var.admin_ssh_public_key
  vnet_address_space    = var.vnet_address_space
  subnet_address_prefix = var.subnet_address_prefix
  admin_users           = var.admin_users
  tags                  = var.tags
}

module "keyvault" {
  source = "./modules/keyvault"

  keyvault_name       = local.keyvault_name
  location            = var.location
  resource_group_name = local.resource_group_name
  vm_name             = local.vm_name
  ssh_private_key     = module.vm_infrastructure.private_key_pem != null ? module.vm_infrastructure.private_key_pem : ""
  admin_users         = var.admin_users
  tags                = var.tags

  depends_on = [module.vm_infrastructure]
}

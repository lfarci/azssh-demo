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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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
  # Compute resource names based on location and workload name
  location_short = {
    "eastus"         = "eus"
    "westus"         = "wus"
    "centralus"      = "cus"
    "northeurope"    = "neu"
    "westeurope"     = "weu"
    "belgiumcentral" = "bec"
  }
  location_code       = lookup(local.location_short, var.location, substr(var.location, 0, 3))
  resource_group_name = "rg-${var.workload_name}-${local.location_code}"
  vm_name             = "vm-${var.workload_name}-${local.location_code}"
  # Key Vault name uses random string for global uniqueness (max 24 chars)
  keyvault_name = "kv-${var.workload_name}-${local.location_code}-${random_string.keyvault_suffix.result}"
  # Storage account name: globally unique, alphanumeric only, 3-24 chars
  storage_account_name = "st${replace(var.workload_name, "-", "")}${local.location_code}${random_string.storage_suffix.result}"
}

resource "random_string" "keyvault_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
  lower   = true
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
  ssh_private_key     = module.vm_infrastructure.private_key_pem
  admin_users         = var.admin_users
  tags                = var.tags

  depends_on = [module.vm_infrastructure]
}

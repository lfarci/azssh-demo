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
  vnet_name           = "vnet-${var.workload_name}-${local.location_code}"
  vm_public_name      = "vm-${var.workload_name}-runner-${local.location_code}"
  vm_private_name     = "vm-${var.workload_name}-private-${local.location_code}"
  # Key Vault name uses random string for global uniqueness (max 24 chars)
  keyvault_name = "kv-${var.workload_name}-${local.location_code}-${random_string.keyvault_suffix.result}"
  # Storage account name: globally unique, alphanumeric only, 3-24 chars
  storage_account_name = "st${replace(var.workload_name, "-", "")}${local.location_code}${random_string.storage_suffix.result}"
}

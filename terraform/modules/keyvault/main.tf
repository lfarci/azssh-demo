data "azurerm_client_config" "current" {}

# Key Vault
resource "azurerm_key_vault" "main" {
  name                       = var.keyvault_name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = var.tags

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge",
      "Recover"
    ]
  }
}

# Store private SSH key as a secret
resource "azurerm_key_vault_secret" "ssh_private_key" {
  count        = var.ssh_private_key != null && var.ssh_private_key != "" ? 1 : 0
  name         = "${var.vm_name}-ssh-private-key"
  value        = var.ssh_private_key
  key_vault_id = azurerm_key_vault.main.id
  tags         = var.tags

  depends_on = [azurerm_key_vault.main]
}

# Access policy for admin users
resource "azurerm_key_vault_access_policy" "admin_users" {
  for_each     = toset(var.admin_users)
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = each.value

  secret_permissions = [
    "Get",
    "List"
  ]
}

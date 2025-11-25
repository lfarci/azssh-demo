output "keyvault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "keyvault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "keyvault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "ssh_private_key_secret_id" {
  description = "ID of the SSH private key secret"
  value       = azurerm_key_vault_secret.ssh_private_key.id
}

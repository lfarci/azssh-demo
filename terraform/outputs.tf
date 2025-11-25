output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vm_public_name" {
  description = "Name of the public virtual machine (GitHub runner)"
  value       = module.vm_public.vm_name
}

output "vm_public_id" {
  description = "ID of the public virtual machine (GitHub runner)"
  value       = module.vm_public.vm_id
}

output "vm_private_name" {
  description = "Name of the private virtual machine"
  value       = module.vm_private.vm_name
}

output "vm_private_id" {
  description = "ID of the private virtual machine"
  value       = module.vm_private.vm_id
}

output "public_ip_address" {
  description = "Public IP address of the public virtual machine (GitHub runner)"
  value       = module.vm_public.public_ip_address
}

output "vm_public_private_ip_address" {
  description = "Private IP address of the public virtual machine"
  value       = module.vm_public.private_ip_address
}

output "vm_private_ip_address" {
  description = "Private IP address of the private virtual machine"
  value       = module.vm_private.private_ip_address
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.network.vnet_name
}

output "subnet_name" {
  description = "Name of the main subnet"
  value       = module.network.subnet_name
}

output "keyvault_name" {
  description = "Name of the Key Vault"
  value       = module.keyvault.keyvault_name
}

output "keyvault_uri" {
  description = "URI of the Key Vault"
  value       = module.keyvault.keyvault_uri
}

output "ssh_connection_command_public" {
  description = "Command to connect to the public VM (GitHub runner) via SSH (requires Azure CLI with SSH extension)"
  value       = "az ssh vm --resource-group ${azurerm_resource_group.main.name} --name ${module.vm_public.vm_name}"
}

output "ssh_connection_command_private" {
  description = "Command to connect to the private VM via SSH through the public VM (requires Azure CLI with SSH extension)"
  value       = "ssh -J ${var.admin_username}@${module.vm_public.public_ip_address} ${var.admin_username}@${module.vm_private.private_ip_address}"
}

output "private_key_pem" {
  description = "Generated SSH private key (only if no key was provided)"
  value       = var.admin_ssh_public_key == "" ? tls_private_key.ssh[0].private_key_pem : null
  sensitive   = true
}

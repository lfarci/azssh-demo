variable "keyvault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine (used for secret naming)"
  type        = string
}

variable "ssh_private_key" {
  description = "SSH private key to store in Key Vault"
  type        = string
  default     = ""
  sensitive   = true
}

variable "admin_users" {
  description = "List of Azure AD user object IDs to grant access to Key Vault"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

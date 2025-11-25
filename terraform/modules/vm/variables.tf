variable "resource_group_name" {
  description = "Name of the Azure resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
}

variable "admin_username" {
  description = "Admin username for the virtual machine"
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key for admin user. If empty, a new key will be generated."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = list(string)
}

variable "admin_users" {
  description = "List of Azure AD user object IDs to assign Virtual Machine Administrator Login role"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

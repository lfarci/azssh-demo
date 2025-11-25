variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "workflow_name" {
  description = "Name of the workflow (used to compute resource names). Max 12 chars for Key Vault name limits."
  type        = string
  default     = "azssh-demo"

  validation {
    condition     = length(var.workflow_name) <= 12
    error_message = "The workflow_name must be 12 characters or less to ensure Key Vault name stays within Azure's 24-character limit."
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "vm_size" {
  description = "Size of the virtual machine"
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Admin username for the virtual machine"
  type        = string
  default     = "azureuser"
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
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "admin_users" {
  description = "List of Azure AD user object IDs to assign Virtual Machine Administrator Login role"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Environment = "Demo"
    Purpose     = "Azure SSH Testing"
  }
}

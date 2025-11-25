output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.vm_infrastructure.resource_group_name
}

output "vm_name" {
  description = "Name of the virtual machine"
  value       = module.vm_infrastructure.vm_name
}

output "vm_id" {
  description = "ID of the virtual machine"
  value       = module.vm_infrastructure.vm_id
}

output "public_ip_address" {
  description = "Public IP address of the virtual machine"
  value       = module.vm_infrastructure.public_ip_address
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = module.vm_infrastructure.vnet_name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = module.vm_infrastructure.subnet_name
}

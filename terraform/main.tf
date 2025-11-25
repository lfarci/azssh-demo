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

resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "tls_private_key" "ssh" {
  count     = var.admin_ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "network" {
  source = "./modules/network"

  resource_group_name   = azurerm_resource_group.main.name
  location              = azurerm_resource_group.main.location
  create_resource_group = false
  vnet_name             = local.vnet_name
  vnet_address_space    = var.vnet_address_space
  subnet_name           = "subnet-main"
  subnet_address_prefix = var.subnet_address_prefix
  tags                  = var.tags

  depends_on = [azurerm_resource_group.main]
}

module "vm_public" {
  source = "./modules/vm"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  vm_name              = local.vm_public_name
  vm_size              = var.vm_public_size
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key != "" ? var.admin_ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  subnet_id            = module.network.subnet_id
  enable_public_ip     = true
  nsg_rules = [
    {
      name                       = "SSH"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]
  admin_users = var.admin_users
  tags = merge(var.tags, {
    Role = "GitHub Runner"
  })

  depends_on = [module.network]
}

module "vm_private" {
  source = "./modules/vm"

  resource_group_name  = azurerm_resource_group.main.name
  location             = azurerm_resource_group.main.location
  vm_name              = local.vm_private_name
  vm_size              = var.vm_private_size
  admin_username       = var.admin_username
  admin_ssh_public_key = var.admin_ssh_public_key != "" ? var.admin_ssh_public_key : tls_private_key.ssh[0].public_key_openssh
  subnet_id            = module.network.subnet_id
  enable_public_ip     = false
  nsg_rules = [
    {
      name                       = "SSH-from-VNet"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    }
  ]
  admin_users = var.admin_users
  tags = merge(var.tags, {
    Role = "Private VM"
  })

  depends_on = [module.network]
}

module "keyvault" {
  source = "./modules/keyvault"

  keyvault_name       = local.keyvault_name
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  vm_name             = local.vm_public_name
  ssh_private_key     = var.admin_ssh_public_key == "" ? tls_private_key.ssh[0].private_key_pem : null
  admin_users         = var.admin_users
  tags                = var.tags

  depends_on = [module.vm_public, module.vm_private]
}

# azssh-demo

Test Azure CLI SSH extension to authenticate to a Linux virtual machine using Azure AD authentication.

## Overview

This repository contains Terraform infrastructure as code (IaC) to deploy an Ubuntu virtual machine in Azure with Azure AD SSH authentication enabled. This allows users to SSH into the VM using their Azure AD credentials without managing SSH keys manually.

## Features

- **Ubuntu Virtual Machine**: Deployed with the latest Ubuntu 22.04 LTS image
- **Virtual Network**: Dedicated VNet with subnet for VM hosting
- **Public Access**: VM is accessible via public IP address
- **Azure AD SSH Authentication**: `AADSSHLoginForLinux` extension enabled
- **Role-Based Access**: Configurable administrator users via Azure RBAC
- **Automated Deployment**: GitHub Actions workflow for CI/CD

## Prerequisites

- Azure subscription
- Azure CLI installed
- Terraform >= 1.0
- Azure AD user account

## Architecture

The infrastructure includes:
- Resource Group
- Virtual Network with Subnet
- Network Security Group (allows SSH on port 22)
- Public IP Address
- Network Interface
- Linux Virtual Machine (Ubuntu 22.04 LTS)
- AADSSHLoginForLinux VM Extension
- Role Assignments for VM Administrator Login

## Usage

### Local Deployment

1. Clone the repository:
   ```bash
   git clone https://github.com/lfarci/azssh-demo.git
   cd azssh-demo/terraform
   ```

2. Login to Azure:
   ```bash
   az login
   ```

3. Copy and configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

4. Get your Azure AD user object ID:
   ```bash
   az ad user show --id your-email@domain.com --query id -o tsv
   ```

5. Edit `terraform.tfvars` and add your user object ID to the `admin_users` list.

6. Initialize Terraform:
   ```bash
   terraform init
   ```

7. Plan the deployment:
   ```bash
   terraform plan
   ```

8. Apply the configuration:
   ```bash
   terraform apply
   ```

### Connect to the VM

After deployment, connect using Azure CLI SSH:

```bash
# Get the VM's public IP
PUBLIC_IP=$(terraform output -raw public_ip_address)

# SSH using Azure AD authentication
az ssh vm --ip $PUBLIC_IP
```

Or specify the resource details:

```bash
az ssh vm --resource-group rg-azssh-demo --name vm-ubuntu-demo
```

## GitHub Actions

The repository includes a GitHub Actions workflow that:
- Validates Terraform configuration
- Checks formatting
- Creates a plan for pull requests
- Applies changes on merge to main

### Required Secrets

Configure these secrets in your GitHub repository:
- `AZURE_CLIENT_ID`: Azure service principal client ID
- `AZURE_CLIENT_SECRET`: Azure service principal client secret
- `AZURE_SUBSCRIPTION_ID`: Azure subscription ID
- `AZURE_TENANT_ID`: Azure tenant ID

## Module Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `resource_group_name` | Name of the Azure resource group | `rg-azssh-demo` |
| `location` | Azure region for resources | `eastus` |
| `vm_name` | Name of the virtual machine | `vm-ubuntu-demo` |
| `vm_size` | Size of the virtual machine | `Standard_B2s` |
| `admin_username` | Admin username for the VM | `azureuser` |
| `vnet_address_space` | Address space for the VNet | `["10.0.0.0/16"]` |
| `subnet_address_prefix` | Address prefix for the subnet | `["10.0.1.0/24"]` |
| `admin_users` | List of Azure AD user object IDs for admin access | `[]` |
| `tags` | Tags to apply to resources | See variables.tf |

## Outputs

- `resource_group_name`: Name of the created resource group
- `vm_name`: Name of the virtual machine
- `vm_id`: Azure resource ID of the VM
- `public_ip_address`: Public IP address of the VM
- `vnet_name`: Name of the virtual network
- `subnet_name`: Name of the subnet

## Security

- SSH access is controlled via Azure AD authentication
- Network Security Group restricts access to SSH port 22
- Role-based access control (RBAC) manages VM administrator permissions
- No SSH keys are stored in the repository

## Clean Up

To destroy the infrastructure:

```bash
cd terraform
terraform destroy
```

## License

This project is provided as-is for demonstration purposes.

# azssh-demo

Test Azure CLI SSH extension to authenticate to a Linux virtual machine using Azure AD authentication.

## Overview

This repository contains Terraform infrastructure as code (IaC) to deploy an Ubuntu virtual machine in Azure with Entra ID SSH authentication enabled. This allows users to SSH into the VM using their Entra ID credentials without managing SSH keys manually.

## Features

- **Ubuntu Virtual Machine**: Deployed with the latest Ubuntu 22.04 LTS image
- **Virtual Network**: Dedicated VNet with subnet for VM hosting
- **Public Access**: VM is accessible via public IP address
- **Azure AD SSH Authentication**: `AADSSHLoginForLinux` extension enabled
- **Key Vault**: Secure storage for SSH private keys
- **Role-Based Access**: Configurable administrator users via Azure RBAC
- **Remote State Management**: Azure Blob Storage backend for Terraform state
- **Computed Resource Names**: Dynamic naming based on workflow name and location
- **Automated Deployment**: GitHub Actions workflow with manual dispatch

## Prerequisites

- Azure subscription
- Azure CLI installed
- Terraform >= 1.0
- Azure AD user account

## Architecture

The infrastructure includes:
- Resource Group (name: `rg-{workflow_name}-{location_code}`)
- Virtual Network with Subnet
- Network Security Group (allows SSH on port 22)
- Public IP Address
- Network Interface
- Linux Virtual Machine (Ubuntu 22.04 LTS, name: `vm-{workflow_name}-{location_code}`)
- AADSSHLoginForLinux VM Extension
- Key Vault for SSH private key storage (with uniqueness hash)
- Role Assignments for VM Administrator Login
- Azure Blob Storage backend for Terraform state

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

3. Configure backend (optional - for remote state):
   ```bash
   cp backend.tfvars.example backend.tfvars
   # Edit backend.tfvars with your Azure Storage details
   ```

4. Copy and configure variables:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

5. Get your Entra ID user object ID:
   ```bash
   az ad user show --id <your-email> --query id -o tsv
   ```

6. Edit `terraform.tfvars` and configure:
   - `subscription_id`: Your Azure subscription ID
   - `workflow_name`: Name for your deployment (used in resource naming)
   - `location`: Azure region
   - `admin_users`: List of Azure AD user object IDs

7. Initialize Terraform:
   ```bash
   # Without remote backend
   terraform init -backend=false
   
   # With remote backend
   terraform init -backend-config=backend.tfvars
   ```

8. Plan the deployment:
   ```bash
   terraform plan -var-file=terraform.tfvars
   ```

9. Apply the configuration:
   ```bash
   terraform apply -var-file=terraform.tfvars
   ```

### Connect to the VM

After deployment, connect using Azure CLI SSH:

```bash
# Get the VM's public IP
PUBLIC_IP=$(terraform output -raw public_ip_address)

# SSH using Azure AD authentication
az ssh vm --ip $PUBLIC_IP
```

Or specify the resource details (resource names are computed from workflow_name and location):

```bash
# For workflow_name="azssh-demo" and location="eastus"
az ssh vm --resource-group rg-azssh-demo-eus --name vm-azssh-demo-eus
```

### Retrieve SSH Private Key from Key Vault

If you need the SSH private key for manual access:

```bash
# Get Key Vault name from Terraform output
KEYVAULT_NAME=$(terraform output -raw keyvault_name)

# Retrieve the private key
az keyvault secret show --vault-name $KEYVAULT_NAME --name vm-azssh-demo-eus-ssh-private-key --query value -o tsv
```

## GitHub Actions

The repository includes a GitHub Actions workflow with manual dispatch trigger that:
- Validates Terraform configuration
- Checks formatting
- Creates a Terraform plan
- Applies changes automatically

### Workflow Inputs

When triggering the workflow manually, provide:
- `subscription_id`: Azure Subscription ID (required)
- `workflow_name`: Workflow name for resource naming (default: `azssh-demo`)
- `location`: Azure region (default: `eastus`)
- `admin_users`: Comma-separated list of Azure AD user object IDs (optional)

### Required Secrets

Configure these secrets in your GitHub repository:

**Azure Authentication:**
- `AZURE_CLIENT_ID`: Azure service principal client ID
- `AZURE_CLIENT_SECRET`: Azure service principal client secret
- `AZURE_TENANT_ID`: Azure tenant ID

**Terraform Backend (for remote state storage):**
- `BACKEND_RESOURCE_GROUP_NAME`: Backend storage resource group name
- `BACKEND_STORAGE_ACCOUNT_NAME`: Backend storage account name
- `BACKEND_CONTAINER_NAME`: Backend container name
- `BACKEND_KEY`: State file name (e.g., `azssh-demo.tfstate`)

## Module Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `subscription_id` | Azure subscription ID | (required) |
| `workflow_name` | Workflow name for resource naming | `azssh-demo` |
| `location` | Azure region for resources | `eastus` |
| `vm_size` | Size of the virtual machine | `Standard_B2s` |
| `admin_username` | Admin username for the VM | `azureuser` |
| `admin_ssh_public_key` | SSH public key (auto-generated if empty) | `""` |
| `vnet_address_space` | Address space for the VNet | `["10.0.0.0/16"]` |
| `subnet_address_prefix` | Address prefix for the subnet | `["10.0.1.0/24"]` |
| `admin_users` | List of Azure AD user object IDs for admin access | `[]` |
| `tags` | Tags to apply to resources | See variables.tf |

### Computed Names

Resource names are automatically computed based on `workflow_name` and `location`:
- Resource Group: `rg-{workflow_name}-{location_code}`
- Virtual Machine: `vm-{workflow_name}-{location_code}`
- Key Vault: `kv-{workflow_name}-{location_code}-{hash}` (includes uniqueness hash)

## Outputs

- `resource_group_name`: Name of the created resource group
- `vm_name`: Name of the virtual machine
- `vm_id`: Azure resource ID of the VM
- `public_ip_address`: Public IP address of the VM
- `vnet_name`: Name of the virtual network
- `subnet_name`: Name of the subnet
- `keyvault_name`: Name of the Key Vault
- `keyvault_uri`: URI of the Key Vault
- `ssh_connection_command`: Ready-to-use SSH command

## Security

- SSH access is controlled via Azure AD authentication
- SSH private keys are securely stored in Azure Key Vault
- Network Security Group restricts access to SSH port 22
- Role-based access control (RBAC) manages VM administrator permissions
- Terraform state stored remotely in Azure Blob Storage
- No sensitive data stored in the repository

## Clean Up

To destroy the infrastructure:

```bash
cd terraform
terraform destroy
```

## License

This project is provided as-is for demonstration purposes.

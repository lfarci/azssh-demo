# azssh-demo

Demo project for deploying Azure VMs with Entra ID SSH authentication using automated scripts and GitHub Actions.

## Quick Start

This repository provides scripts to automate the deployment of Azure infrastructure using Terraform and GitHub Actions.

### Prerequisites

- Azure CLI installed and authenticated (`az login`)
- GitHub CLI installed and authenticated (`gh auth login`)
- Azure subscription with appropriate permissions

### Deployment Steps

Navigate to the `scripts/` directory and run the scripts in order:

#### 1. Setup Service Principal

```bash
./00-setup-service-principal.sh
```

Creates an Entra ID service principal with OIDC federation for GitHub Actions. Automatically configures:
- Federated credentials for GitHub OIDC authentication
- Contributor and User Access Administrator roles at subscription level
- GitHub repository secrets (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`)

#### 2. Deploy Storage Account

```bash
./01-deploy-storage.sh
```

Deploys an Azure Storage Account for Terraform remote state via GitHub Actions workflow. Provisions:
- Resource group
- Storage account with specified replication type
- Container for Terraform state files
- Optional RBAC assignments for admin users

#### 3. Configure Terraform Secrets

```bash
./02-configure-terraform-secrets.sh
```

Sets up GitHub repository secrets for Terraform backend configuration:
- `TF_BACKEND_RESOURCE_GROUP_NAME`
- `TF_BACKEND_STORAGE_ACCOUNT_NAME`
- `TF_BACKEND_CONTAINER_NAME`

#### 4. Deploy Virtual Machine

```bash
./03-deploy-virtual-machine.sh
```

Triggers GitHub Actions workflow to deploy VM infrastructure via Terraform. Deploys:
- Virtual network and subnet
- Network security group
- Ubuntu 22.04 LTS VM with public IP
- Azure AD SSH extension (`AADSSHLoginForLinux`)
- Key Vault for SSH private key storage
- RBAC role assignments for admin access

### Connect to VM

After deployment completes:

```bash
az ssh vm -g <resource-group-name> -n <vm-name>
```

Resource names follow the pattern: `rg-{workload-name}` and `vm-{workload-name}-runner-{location-code}`.

### Setup Self-Hosted GitHub Actions Runner

The deployed VM can be configured as a self-hosted GitHub Actions runner:

1. SSH into the VM:
   ```bash
   az ssh vm -g <resource-group-name> -n <vm-name>
   ```

2. Follow GitHub's instructions to install and configure the runner:
   - Go to your repository Settings → Actions → Runners → New self-hosted runner
   - Select Linux and follow the provided commands to download, configure, and start the runner
   - Use a label like `self-hosted` or `azure-vm` when configuring

3. Once configured, you can use the runner in workflows by specifying:
   ```yaml
   runs-on: self-hosted
   ```

4. Trigger SSH workflow from your local machine using the runner:
   ```bash
   ./08-trigger-ssh-workflow.sh
   ```
   This will prompt for the runner label, VM name, and resource group, then trigger a workflow that uses the self-hosted runner to SSH into the VM.

### Clean Up

Delete resources in reverse order:

```bash
./04-delete-virtual-machine.sh  # Delete VM infrastructure
./05-delete-storage.sh          # Delete storage account
./06-delete-service-principal.sh # Delete service principal
```

## Additional Scripts

- `07-add-federated-credential.sh` - Add additional federated credentials to existing service principal
- `08-trigger-ssh-workflow.sh` - Trigger SSH connection workflow via GitHub Actions

## Architecture

The infrastructure includes:
- Resource group
- Virtual network with subnet
- Network security group (allows SSH on port 22)
- Ubuntu 22.04 LTS VM with public IP
- AADSSHLoginForLinux extension
- Key Vault for SSH key storage
- Terraform state stored in Azure Blob Storage

All scripts are interactive and will prompt for required inputs with sensible defaults.

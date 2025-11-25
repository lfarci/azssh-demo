#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the library
source "$SCRIPT_DIR/library.sh"

# Verify prerequisites
verify_prerequisites
verify_azure_auth
verify_github_auth
verify_github_secrets "AZURE_CLIENT_ID" "AZURE_TENANT_ID" "AZURE_SUBSCRIPTION_ID"

echo ""
print_info "=== Configure Terraform Backend Secrets ==="
echo ""

# Get subscription ID
subscription_id=$(get_subscription_id)

# Set subscription
az account set --subscription "$subscription_id"

# Collect inputs
echo ""
print_info "Please provide the following inputs:"
echo ""

read_with_default "Workload name" "azssh-demo" workload_name

# Generate resource group name based on workload name (matches Terraform logic)
resource_group_name="rg-${workload_name}"

# Check if resource group exists
echo ""
print_info "Searching for resource group '$resource_group_name'..."
if ! az group show --name "$resource_group_name" --subscription "$subscription_id" &>/dev/null; then
    print_error "Resource group '$resource_group_name' does not exist"
    print_info "Please run the deploy storage script first: ./scripts/01-deploy-storage.sh"
    exit 1
fi

print_success "Found resource group: $resource_group_name"

# Find storage accounts in the resource group
echo ""
print_info "Searching for storage accounts in resource group..."
storage_accounts=$(az storage account list \
    --resource-group "$resource_group_name" \
    --subscription "$subscription_id" \
    --query "[].name" -o tsv)

if [ -z "$storage_accounts" ]; then
    print_error "No storage accounts found in resource group '$resource_group_name'"
    print_info "Please run the deploy storage script first: ./scripts/01-deploy-storage.sh"
    exit 1
fi

# Count storage accounts
storage_account_count=$(echo "$storage_accounts" | wc -l)

if [ "$storage_account_count" -eq 1 ]; then
    storage_account_name="$storage_accounts"
    print_success "Found storage account: $storage_account_name"
else
    print_warning "Found multiple storage accounts in resource group:"
    echo "$storage_accounts" | nl
    echo ""
    read -p "Enter the number of the storage account to use: " account_number
    storage_account_name=$(echo "$storage_accounts" | sed -n "${account_number}p")
    
    if [ -z "$storage_account_name" ]; then
        print_error "Invalid selection"
        exit 1
    fi
    
    print_info "Selected storage account: $storage_account_name"
fi

# Get container name
echo ""
print_info "Searching for blob containers in storage account..."
containers=$(az storage container list \
    --account-name "$storage_account_name" \
    --auth-mode login \
    --query "[].name" -o tsv 2>/dev/null || true)

if [ -z "$containers" ]; then
    print_warning "Could not list containers (you may need Storage Blob Data Reader role)"
    read_with_default "Container name for Terraform state" "tfstate" container_name
else
    container_count=$(echo "$containers" | wc -l)
    
    if [ "$container_count" -eq 1 ]; then
        container_name="$containers"
        print_success "Found container: $container_name"
    else
        print_info "Found multiple containers:"
        echo "$containers" | nl
        echo ""
        read_with_default "Container name for Terraform state" "tfstate" container_name
    fi
fi

# Get storage account details
echo ""
print_info "Retrieving storage account details..."
storage_account_id=$(az storage account show \
    --name "$storage_account_name" \
    --resource-group "$resource_group_name" \
    --query "id" -o tsv)

# Display summary
echo ""
print_info "=== Configuration Summary ==="
echo "  Subscription ID: $subscription_id"
echo "  Resource Group: $resource_group_name"
echo "  Storage Account: $storage_account_name"
echo "  Container Name: $container_name"
echo "  Storage Account ID: $storage_account_id"
echo ""

read -p "Proceed with setting GitHub secrets? (y/n) [y]: " confirm
confirm=${confirm:-y}

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_warning "Configuration cancelled"
    exit 0
fi

# Set GitHub secrets
echo ""
print_info "Setting GitHub repository secrets for Terraform backend..."

gh secret set TF_BACKEND_RESOURCE_GROUP_NAME --body "$resource_group_name"
print_success "Set TF_BACKEND_RESOURCE_GROUP_NAME"

gh secret set TF_BACKEND_STORAGE_ACCOUNT_NAME --body "$storage_account_name"
print_success "Set TF_BACKEND_STORAGE_ACCOUNT_NAME"

gh secret set TF_BACKEND_CONTAINER_NAME --body "$container_name"
print_success "Set TF_BACKEND_CONTAINER_NAME"

echo ""
print_success "=== Configuration Complete ==="
echo ""
print_info "GitHub Secrets Set:"
echo "  TF_BACKEND_RESOURCE_GROUP_NAME: $resource_group_name"
echo "  TF_BACKEND_STORAGE_ACCOUNT_NAME: $storage_account_name"
echo "  TF_BACKEND_CONTAINER_NAME: $container_name"
echo ""
print_info "Your Terraform backend is now configured with:"
echo ""
echo "  terraform {"
echo "    backend \"azurerm\" {"
echo "      resource_group_name  = \"$resource_group_name\""
echo "      storage_account_name = \"$storage_account_name\""
echo "      container_name       = \"$container_name\""
echo "      key                  = \"terraform.tfstate\""
echo "      use_oidc             = true"
echo "    }"
echo "  }"
echo ""
print_info "These secrets can be used in GitHub Actions workflows to configure"
print_info "the Terraform backend dynamically."
echo ""

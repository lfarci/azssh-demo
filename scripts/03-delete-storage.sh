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

echo ""
print_info "=== Delete Storage Account Workflow ==="
echo ""

# Get subscription ID
subscription_id=$(get_subscription_id)

# Collect workflow inputs
echo ""
print_info "Please provide the following inputs:"
echo ""

require_input "Resource group name" resource_group_name

# Check if resource group exists and list storage accounts
if az group show --name "$resource_group_name" --subscription "$subscription_id" &> /dev/null; then
    print_info "Found resource group: $resource_group_name"
    
    storage_accounts=$(az storage account list --resource-group "$resource_group_name" --subscription "$subscription_id" --query "[].name" -o tsv)
    
    if [ -n "$storage_accounts" ]; then
        echo ""
        print_info "Storage accounts in this resource group:"
        while IFS= read -r account; do
            echo "  - $account"
        done <<< "$storage_accounts"
        echo ""
    else
        print_warning "No storage accounts found in this resource group"
    fi
else
    print_warning "Resource group '$resource_group_name' not found in subscription"
fi

require_input "Storage account name to delete" storage_account_name

# Verify storage account exists
if az storage account show --name "$storage_account_name" --resource-group "$resource_group_name" --subscription "$subscription_id" &> /dev/null; then
    print_info "Storage account '$storage_account_name' found"
else
    print_warning "Storage account '$storage_account_name' not found (will attempt deletion anyway)"
fi

read_with_default "Also delete the resource group '$resource_group_name'? (yes/no)" "no" delete_resource_group

# Display summary
echo ""
print_warning "=== DELETION SUMMARY ==="
echo "  Subscription ID: $subscription_id"
echo "  Resource Group: $resource_group_name"
echo "  Storage Account: $storage_account_name"
echo "  Delete Resource Group: $delete_resource_group"
echo ""

print_error "⚠️  WARNING: This action cannot be undone!"
echo ""

read -p "Are you ABSOLUTELY SURE you want to delete these resources? (yes/no) [no]: " confirm
confirm=${confirm:-no}

if [[ "$confirm" != "yes" ]]; then
    print_warning "Deletion cancelled"
    exit 0
fi

# Final confirmation for resource group deletion
if [[ "$delete_resource_group" == "yes" ]]; then
    echo ""
    print_error "⚠️  You are about to delete the ENTIRE resource group!"
    read -p "Type the resource group name to confirm: " rg_confirm
    
    if [[ "$rg_confirm" != "$resource_group_name" ]]; then
        print_error "Resource group name does not match. Deletion cancelled."
        exit 1
    fi
fi

# Trigger GitHub workflow
trigger_workflow "03-delete-storage.yml" \
    -f subscription_id="$subscription_id" \
    -f resource_group_name="$resource_group_name" \
    -f storage_account_name="$storage_account_name" \
    -f delete_resource_group="$delete_resource_group"

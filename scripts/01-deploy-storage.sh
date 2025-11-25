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
verify_github_secrets "AZURE_CLIENT_ID" "AZURE_TENANT_ID"

echo ""
print_info "=== Deploy Storage Account Workflow ==="
echo ""

# Get subscription ID
subscription_id=$(get_subscription_id)

# Get current user object ID for admin access
current_user_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")

# Collect workflow inputs
echo ""
print_info "Please provide the following inputs:"
echo ""

read_with_default "Workload name" "azssh-demo" workload_name
read_with_default "Azure region" "belgiumcentral" location

# Generate resource group name based on workload name
resource_group_name="rg-${workload_name}"

# Check if resource group exists
echo ""
print_info "Checking if resource group '$resource_group_name' exists..."
if az group show --name "$resource_group_name" --subscription "$subscription_id" &>/dev/null; then
    print_success "Resource group '$resource_group_name' exists"
    
    # Check for existing storage accounts in the resource group
    echo ""
    print_info "Checking for existing storage accounts in resource group..."
    existing_storage_accounts=$(az storage account list \
        --resource-group "$resource_group_name" \
        --subscription "$subscription_id" \
        --query "[].name" -o tsv)
    
    if [ -n "$existing_storage_accounts" ]; then
        # Take the first storage account
        storage_account_name=$(echo "$existing_storage_accounts" | head -n 1)
        print_warning "Found existing storage account in resource group '$resource_group_name': $storage_account_name"
        echo ""
        
        # Ask user what they want to do
        echo "What would you like to do?"
        echo "  1) Update existing storage account"
        echo "  2) Create a new storage account"
        echo "  3) Cancel"
        read -p "Select option (1/2/3) [1]: " storage_action
        storage_action=${storage_action:-1}
        
        case $storage_action in
            1)
                print_info "Will update existing storage account: $storage_account_name"
                update_existing=true
                ;;
            2)
                print_info "Will create a new storage account"
                update_existing=false
                ;;
            3)
                print_warning "Operation cancelled"
                exit 0
                ;;
            *)
                print_error "Invalid option selected"
                exit 1
                ;;
        esac
    else
        print_info "No existing storage accounts found in resource group"
        update_existing=false
    fi
else
    print_info "Resource group '$resource_group_name' does not exist. It will be created."
    update_existing=false
fi

echo ""
read_with_default "Storage container name" "tfstate" storage_container_name
read_with_default "Storage replication type (LRS/GRS/RAGRS/ZRS)" "LRS" storage_replication_type

if [ -n "$current_user_id" ]; then
    read -p "Grant Storage Blob Data Contributor access to your user? (y/n) [y]: " grant_access
    grant_access=${grant_access:-y}
    
    if [[ "$grant_access" == "y" || "$grant_access" == "Y" ]]; then
        admin_users=$current_user_id
    else
        admin_users=""
    fi
    
    read -p "Add additional admin users (comma-separated object IDs) [none]: " additional_users
    if [ -n "$additional_users" ]; then
        if [ -n "$admin_users" ]; then
            admin_users="$admin_users,$additional_users"
        else
            admin_users="$additional_users"
        fi
    fi
else
    read -p "Admin user object IDs (comma-separated) [none]: " admin_users
fi

# Display summary
echo ""
print_info "=== Deployment Summary ==="
echo "  Subscription ID: $subscription_id"
echo "  Resource Group: $resource_group_name"
echo "  Workload Name: $workload_name"
echo "  Location: $location"
if [ "$update_existing" = true ]; then
    echo "  Action: Update existing storage account"
    echo "  Storage Account: $storage_account_name"
else
    echo "  Action: Create new storage account"
fi
echo "  Container Name: $storage_container_name"
echo "  Replication Type: $storage_replication_type"
echo "  Admin Users: ${admin_users:-none}"
echo ""

read -p "Proceed with deployment? (y/n) [y]: " confirm
confirm=${confirm:-y}

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Trigger GitHub workflow
if [ "$update_existing" = true ]; then
    trigger_workflow "00-deploy-storage.yml" \
        -f subscription_id="$subscription_id" \
        -f workload_name="$workload_name" \
        -f location="$location" \
        -f storage_container_name="$storage_container_name" \
        -f storage_replication_type="$storage_replication_type" \
        -f admin_users="$admin_users" \
        -f storage_account_name="$storage_account_name"
else
    trigger_workflow "00-deploy-storage.yml" \
        -f subscription_id="$subscription_id" \
        -f workload_name="$workload_name" \
        -f location="$location" \
        -f storage_container_name="$storage_container_name" \
        -f storage_replication_type="$storage_replication_type" \
        -f admin_users="$admin_users"
fi

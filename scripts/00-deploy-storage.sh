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
echo "  Workload Name: $workload_name"
echo "  Location: $location"
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
trigger_workflow "00-deploy-storage.yml" \
    -f subscription_id="$subscription_id" \
    -f workload_name="$workload_name" \
    -f location="$location" \
    -f storage_container_name="$storage_container_name" \
    -f storage_replication_type="$storage_replication_type" \
    -f admin_users="$admin_users"

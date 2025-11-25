#!/bin/bash

# Script to trigger the VM deployment GitHub workflow

set -e

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/library.sh"

# Main script
main() {
    echo "=========================================="
    echo "Trigger VM Deployment Workflow"
    echo "=========================================="
    echo ""

    # Verify prerequisites
    verify_prerequisites
    verify_azure_auth
    verify_github_auth

    # Verify required secrets
    verify_github_secrets \
        "AZURE_CLIENT_ID" \
        "AZURE_CLIENT_SECRET" \
        "AZURE_TENANT_ID" \
        "BACKEND_RESOURCE_GROUP_NAME" \
        "BACKEND_STORAGE_ACCOUNT_NAME" \
        "BACKEND_CONTAINER_NAME" \
        "BACKEND_KEY"

    # Get subscription ID
    subscription_id=$(get_subscription_id)

    # Get other required inputs
    echo ""
    read_with_default "Enter workload name" "azssh-demo" workload_name
    read_with_default "Enter Azure region" "eastus" location
    read_with_default "Enter VM name" "demo-vm" vm_name
    read_with_default "Enter GitHub environment" "production" environment
    
    echo ""
    print_info "Optional: Enter comma-separated Entra ID user object IDs for admin access"
    print_info "Leave empty if you don't want to add additional admin users"
    read -p "Admin user object IDs (optional): " admin_users

    # Confirm before triggering
    echo ""
    print_info "Deployment configuration:"
    echo "  Subscription ID: $subscription_id"
    echo "  Workload Name: $workload_name"
    echo "  Location: $location"
    echo "  VM Name: $vm_name"
    echo "  Environment: $environment"
    if [ -n "$admin_users" ]; then
        echo "  Admin Users: $admin_users"
    fi
    echo ""
    read -p "Trigger deployment with these settings? (y/n) [y]: " confirm
    confirm=${confirm:-y}

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_warning "Deployment cancelled"
        exit 0
    fi

    # Build workflow inputs
    workflow_args=(
        "-f" "subscription_id=$subscription_id"
        "-f" "workload_name=$workload_name"
        "-f" "location=$location"
        "-f" "vm_name=$vm_name"
        "-f" "environment=$environment"
    )

    if [ -n "$admin_users" ]; then
        workflow_args+=("-f" "admin_users=$admin_users")
    fi

    # Trigger the workflow
    echo ""
    trigger_workflow "02-deploy-virtual-machine.yml" "${workflow_args[@]}"
}

# Run main function
main

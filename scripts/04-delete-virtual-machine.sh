#!/bin/bash

# Script to trigger the VM destroy GitHub workflow

set -e

# Source the shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/library.sh"

# Main script
main() {
    echo "=========================================="
    echo "Trigger VM Destroy Workflow"
    echo "=========================================="
    echo ""

    # Verify prerequisites
    verify_prerequisites
    verify_azure_auth
    verify_github_auth

    # Verify required secrets
    verify_github_secrets \
        "AZURE_CLIENT_ID" \
        "AZURE_TENANT_ID" \
        "TF_BACKEND_RESOURCE_GROUP_NAME" \
        "TF_BACKEND_STORAGE_ACCOUNT_NAME" \
        "TF_BACKEND_CONTAINER_NAME"

    # Get subscription ID
    subscription_id=$(get_subscription_id)

    # Get other required inputs
    echo ""
    read_with_default "Enter workload name" "azssh-demo" workload_name
    read_with_default "Enter Azure region" "eastus" location
    read_with_default "Enter GitHub environment" "production" environment

    # Confirm before triggering
    echo ""
    print_warning "⚠️  WARNING: This will destroy all VM infrastructure resources!"
    echo ""
    print_info "Destroy configuration:"
    echo "  Action: destroy"
    echo "  Subscription ID: $subscription_id"
    echo "  Workload Name: $workload_name"
    echo "  Location: $location"
    echo "  Environment: $environment"
    echo ""
    
    read -p "Are you sure you want to destroy these resources? (y/n) [n]: " confirm
    confirm=${confirm:-n}

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        print_warning "Destroy cancelled"
        exit 0
    fi

    # Build workflow inputs
    workflow_args=(
        "-f" "action=destroy"
        "-f" "subscription_id=$subscription_id"
        "-f" "workload_name=$workload_name"
        "-f" "location=$location"
        "-f" "environment=$environment"
    )

    # Trigger the workflow
    echo ""
    trigger_workflow "02-deploy-virtual-machine.yml" "${workflow_args[@]}"
}

# Run main function
main

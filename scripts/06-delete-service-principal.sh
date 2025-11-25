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
print_info "=== Delete Service Principal and GitHub Secrets ==="
echo ""

# Get subscription ID
subscription_id=$(get_subscription_id)

# Set subscription
az account set --subscription "$subscription_id"

# Get GitHub repository information
print_info "Detecting GitHub repository information..."
repo_full=$(gh repo view --json nameWithOwner -q .nameWithOwner)
repo_owner=$(echo "$repo_full" | cut -d'/' -f1)
repo_name=$(echo "$repo_full" | cut -d'/' -f2)
print_success "Repository: $repo_full"

# Collect inputs
echo ""
print_info "Please provide the service principal name to delete:"
echo ""

read_with_default "Service Principal display name" "sp-${repo_name}-oidc" sp_name

# Check if service principal exists
print_info "Checking if service principal exists..."
app_id=$(az ad app list --display-name "$sp_name" --query "[0].appId" -o tsv)

if [ -z "$app_id" ]; then
    print_warning "Service principal '$sp_name' not found"
    sp_exists=false
else
    print_success "Found service principal with ID: $app_id"
    sp_exists=true
fi

# Check GitHub secrets
print_info "Checking GitHub secrets..."
secrets_to_delete=()

for secret in "AZURE_CLIENT_ID" "AZURE_TENANT_ID" "AZURE_SUBSCRIPTION_ID"; do
    if gh secret list | grep -q "^$secret"; then
        secrets_to_delete+=("$secret")
    fi
done

if [ ${#secrets_to_delete[@]} -gt 0 ]; then
    print_success "Found ${#secrets_to_delete[@]} GitHub secret(s) to delete"
    secrets_exist=true
else
    print_warning "No GitHub secrets found"
    secrets_exist=false
fi

# Display summary
echo ""
print_info "=== Deletion Summary ==="
if [ "$sp_exists" = true ]; then
    echo "  Service Principal: $sp_name (ID: $app_id)"
    echo "    - Federated credentials will be deleted"
    echo "    - Role assignments will be removed"
    echo "    - Application registration will be deleted"
fi

if [ "$secrets_exist" = true ]; then
    echo "  GitHub Secrets to delete:"
    for secret in "${secrets_to_delete[@]}"; do
        echo "    - $secret"
    done
fi

if [ "$sp_exists" = false ] && [ "$secrets_exist" = false ]; then
    print_warning "Nothing to delete"
    exit 0
fi

echo ""
print_warning "This action cannot be undone!"
read -p "Proceed with deletion? (y/n) [n]: " confirm
confirm=${confirm:-n}

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_info "Deletion cancelled"
    exit 0
fi

echo ""

# Delete role assignments
if [ "$sp_exists" = true ]; then
    print_info "Removing role assignments..."
    role_assignments=$(az role assignment list --assignee "$app_id" --query "[].id" -o tsv)
    
    if [ -n "$role_assignments" ]; then
        echo "$role_assignments" | while read -r role_id; do
            az role assignment delete --ids "$role_id"
        done
        print_success "Role assignments removed"
    else
        print_info "No role assignments found"
    fi
    
    # Delete service principal and application
    print_info "Deleting service principal and application registration..."
    az ad app delete --id "$app_id"
    print_success "Service principal and application deleted"
fi

# Delete GitHub secrets
if [ "$secrets_exist" = true ]; then
    print_info "Deleting GitHub secrets..."
    for secret in "${secrets_to_delete[@]}"; do
        gh secret delete "$secret"
        print_success "Deleted secret: $secret"
    done
fi

echo ""
print_success "=== Deletion Complete ==="
echo ""

if [ "$sp_exists" = true ]; then
    print_info "Deleted Service Principal:"
    echo "  Name: $sp_name"
    echo "  Application ID: $app_id"
    echo ""
fi

if [ "$secrets_exist" = true ]; then
    print_info "Deleted GitHub Secrets:"
    for secret in "${secrets_to_delete[@]}"; do
        echo "  - $secret"
    done
    echo ""
fi

print_info "Your GitHub Actions will no longer be able to authenticate to Azure."
echo ""

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
print_info "=== Setup Service Principal for OIDC ==="
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

# Get tenant ID
tenant_id=$(az account show --query tenantId -o tsv)

# Collect inputs
echo ""
print_info "Please provide the following inputs:"
echo ""

read_with_default "Service Principal display name" "sp-${repo_name}-oidc" sp_name
read_with_default "GitHub branch/environment for federation" "main" federation_subject

# Ask about federation subject type
echo ""
echo "Federation subject types:"
echo "  1. Branch (default) - ref:refs/heads/<branch-name>"
echo "  2. Pull Request - pull_request"
echo "  3. Environment - environment:<environment-name>"
echo "  4. Tag - ref:refs/tags/<tag-name>"
echo ""
read -p "Select subject type (1-4) [1]: " subject_type
subject_type=${subject_type:-1}

case $subject_type in
    1)
        subject="repo:${repo_full}:ref:refs/heads/${federation_subject}"
        ;;
    2)
        subject="repo:${repo_full}:pull_request"
        ;;
    3)
        subject="repo:${repo_full}:environment:${federation_subject}"
        ;;
    4)
        subject="repo:${repo_full}:ref:refs/tags/${federation_subject}"
        ;;
    *)
        print_error "Invalid subject type"
        exit 1
        ;;
esac

# Display summary
echo ""
print_info "=== Configuration Summary ==="
echo "  Subscription ID: $subscription_id"
echo "  Tenant ID: $tenant_id"
echo "  Repository: $repo_full"
echo "  Service Principal Name: $sp_name"
echo "  Federation Subject: $subject"
echo ""

read -p "Proceed with setup? (y/n) [y]: " confirm
confirm=${confirm:-y}

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_warning "Setup cancelled"
    exit 0
fi

# Create or get service principal
print_info "Checking if service principal exists..."
app_id=$(az ad app list --display-name "$sp_name" --query "[0].appId" -o tsv)

if [ -z "$app_id" ]; then
    print_info "Creating new Entra ID application..."
    app_id=$(az ad app create --display-name "$sp_name" --query appId -o tsv)
    print_success "Created application with ID: $app_id"
    
    print_info "Creating service principal..."
    az ad sp create --id "$app_id"
    print_success "Service principal created"
    
    # Wait a bit for propagation
    sleep 10
else
    print_warning "Application already exists with ID: $app_id"
    read -p "Do you want to update the existing application? (y/n) [y]: " update_app
    update_app=${update_app:-y}
    
    if [[ "$update_app" != "y" && "$update_app" != "Y" ]]; then
        print_info "Using existing application without changes"
    fi
fi

# Get object ID of the service principal
sp_object_id=$(az ad sp show --id "$app_id" --query id -o tsv)
print_success "Service Principal Object ID: $sp_object_id"

# Configure federated credential
print_info "Configuring federated credential for GitHub OIDC..."

# Create a unique credential name based on the subject
credential_name=$(echo "$subject" | sed 's/[^a-zA-Z0-9-]/-/g' | cut -c1-80)

# Check if credential already exists
existing_cred=$(az ad app federated-credential list --id "$app_id" --query "[?name=='$credential_name'].name" -o tsv)

if [ -n "$existing_cred" ]; then
    print_warning "Federated credential '$credential_name' already exists"
    read -p "Do you want to delete and recreate it? (y/n) [n]: " recreate_cred
    recreate_cred=${recreate_cred:-n}
    
    if [[ "$recreate_cred" == "y" || "$recreate_cred" == "Y" ]]; then
        print_info "Deleting existing credential..."
        az ad app federated-credential delete --id "$app_id" --federated-credential-id "$credential_name"
        print_success "Deleted existing credential"
    else
        print_info "Keeping existing credential"
        skip_credential=true
    fi
fi

if [ "$skip_credential" != "true" ]; then
    print_info "Creating federated credential..."
    az ad app federated-credential create \
        --id "$app_id" \
        --parameters "{
            \"name\": \"$credential_name\",
            \"issuer\": \"https://token.actions.githubusercontent.com\",
            \"subject\": \"$subject\",
            \"audiences\": [\"api://AzureADTokenExchange\"]
        }"
    print_success "Federated credential created"
fi

# Assign Contributor role at subscription level
print_info "Assigning Contributor role to service principal..."
role_exists=$(az role assignment list --assignee "$app_id" --role "Contributor" --scope "/subscriptions/$subscription_id" --query "[0].id" -o tsv)

if [ -z "$role_exists" ]; then
    az role assignment create \
        --assignee "$app_id" \
        --role "Contributor" \
        --scope "/subscriptions/$subscription_id"
    print_success "Contributor role assigned"
else
    print_warning "Contributor role already assigned"
fi

# Set GitHub secrets
echo ""
print_info "Setting GitHub repository secrets..."

gh secret set AZURE_CLIENT_ID --body "$app_id"
print_success "Set AZURE_CLIENT_ID"

gh secret set AZURE_TENANT_ID --body "$tenant_id"
print_success "Set AZURE_TENANT_ID"

gh secret set AZURE_SUBSCRIPTION_ID --body "$subscription_id"
print_success "Set AZURE_SUBSCRIPTION_ID"

echo ""
print_success "=== Setup Complete ==="
echo ""
print_info "Service Principal Details:"
echo "  Application (Client) ID: $app_id"
echo "  Tenant ID: $tenant_id"
echo "  Subscription ID: $subscription_id"
echo "  Federation Subject: $subject"
echo ""
print_info "GitHub Secrets Set:"
echo "  AZURE_CLIENT_ID"
echo "  AZURE_TENANT_ID"
echo "  AZURE_SUBSCRIPTION_ID"
echo ""
print_info "Your GitHub Actions can now authenticate to Azure using:"
echo ""
echo "  - uses: azure/login@v2"
echo "    with:"
echo "      client-id: \${{ secrets.AZURE_CLIENT_ID }}"
echo "      tenant-id: \${{ secrets.AZURE_TENANT_ID }}"
echo "      subscription-id: \${{ secrets.AZURE_SUBSCRIPTION_ID }}"
echo ""

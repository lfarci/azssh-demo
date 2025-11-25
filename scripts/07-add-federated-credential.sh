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
print_info "=== Add Federated Credential to Existing Service Principal ==="
echo ""

# Get GitHub repository information
print_info "Detecting GitHub repository information..."
repo_full=$(gh repo view --json nameWithOwner -q .nameWithOwner)
repo_owner=$(echo "$repo_full" | cut -d'/' -f1)
repo_name=$(echo "$repo_full" | cut -d'/' -f2)
print_success "Repository: $repo_full"

# Get the service principal name
read_with_default "Service Principal display name" "sp-${repo_name}-oidc" sp_name

# Check if service principal exists
print_info "Looking for service principal..."
app_id=$(az ad app list --display-name "$sp_name" --query "[0].appId" -o tsv)

if [ -z "$app_id" ]; then
    print_error "Service principal '$sp_name' not found"
    print_info "Run ./scripts/00-setup-service-principal.sh first"
    exit 1
fi

print_success "Found service principal: $app_id"

# Show existing federated credentials
print_info "Existing federated credentials:"
az ad app federated-credential list --id "$app_id" --query "[].{Name:name, Subject:subject}" -o table

echo ""
read_with_default "GitHub environment name for federation" "production" environment_name

# Build the subject
subject="repo:${repo_full}:environment:${environment_name}"

# Display summary
echo ""
print_info "=== Configuration Summary ==="
echo "  Repository: $repo_full"
echo "  Service Principal: $sp_name ($app_id)"
echo "  Federation Subject: $subject"
echo ""

read -p "Proceed with adding this credential? (y/n) [y]: " confirm
confirm=${confirm:-y}

if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    print_warning "Operation cancelled"
    exit 0
fi

# Create a unique credential name based on the subject
credential_name=$(echo "$subject" | sed 's/[^a-zA-Z0-9-]/-/g' | cut -c1-80)

# Check if credential already exists
existing_cred=$(az ad app federated-credential list --id "$app_id" --query "[?name=='$credential_name'].name" -o tsv)

if [ -n "$existing_cred" ]; then
    print_warning "Federated credential '$credential_name' already exists"
    print_info "No changes needed"
    exit 0
fi

# Create the federated credential
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

echo ""
print_success "=== Setup Complete ==="
echo ""
print_info "The service principal can now authenticate from GitHub environment: $environment_name"
echo ""

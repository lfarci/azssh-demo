#!/bin/bash

# Shared library functions for deployment scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

print_error() {
    echo -e "${RED}✗ ${NC}$1"
}

print_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_error "$1 is not installed. Please install it first."
        exit 1
    fi
}

# Function to verify prerequisites
verify_prerequisites() {
    print_info "Checking prerequisites..."
    check_command az
    check_command gh
    print_success "All required commands are available"
}

# Function to verify Azure CLI authentication
verify_azure_auth() {
    print_info "Checking Azure CLI authentication..."
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    print_success "Azure CLI authentication verified"
}

# Function to verify GitHub CLI authentication
verify_github_auth() {
    print_info "Checking GitHub CLI authentication..."
    if ! gh auth status &> /dev/null; then
        print_error "Not logged in to GitHub. Please run 'gh auth login' first."
        exit 1
    fi
    print_success "GitHub CLI authentication verified"
}

# Function to verify GitHub repository secrets
verify_github_secrets() {
    local required_secrets=("$@")
    local missing_secrets=()
    
    print_info "Checking GitHub repository secrets..."
    
    for secret in "${required_secrets[@]}"; do
        # Use gh secret list to check if secret exists
        if ! gh secret list | grep -q "^$secret"; then
            missing_secrets+=("$secret")
        fi
    done
    
    if [ ${#missing_secrets[@]} -gt 0 ]; then
        print_error "Missing required GitHub repository secrets:"
        for secret in "${missing_secrets[@]}"; do
            echo "  - $secret"
        done
        echo ""
        print_info "Please set these secrets in your GitHub repository:"
        echo "  gh secret set SECRET_NAME"
        echo "  Or via GitHub UI: Settings > Secrets and variables > Actions"
        exit 1
    fi
    
    print_success "All required GitHub secrets are configured"
}

# Function to get and confirm subscription
get_subscription_id() {
    local current_sub_id=$(az account show --query id -o tsv)
    local current_sub_name=$(az account show --query name -o tsv)

    print_info "Current Azure Subscription:"
    echo "  ID: $current_sub_id"
    echo "  Name: $current_sub_name"
    echo ""

    read -p "Use this subscription ($current_sub_id)? (y/n) [y]: " use_current
    use_current=${use_current:-y}

    if [[ "$use_current" != "y" && "$use_current" != "Y" ]]; then
        print_info "Available subscriptions:"
        az account list --query "[].{Name:name, ID:id, State:state}" -o table
        echo ""
        read -p "Enter subscription ID: " subscription_id
        echo "$subscription_id"
    else
        echo "$current_sub_id"
    fi
}

# Function to trigger GitHub workflow and show instructions
trigger_workflow() {
    local workflow_file="$1"
    shift
    local args=("$@")

    print_info "Triggering GitHub workflow..."

    gh workflow run "$workflow_file" "${args[@]}"

    if [ $? -eq 0 ]; then
        print_success "Workflow triggered successfully!"
        echo ""
        print_info "To view the workflow run:"
        echo "  gh run list --workflow=$workflow_file"
        echo "  gh run watch"
    else
        print_error "Failed to trigger workflow"
        exit 1
    fi
}

# Function to read user input with default value
read_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        input=${input:-$default}
    else
        read -p "$prompt: " input
    fi
    
    eval "$var_name='$input'"
}

# Function to require non-empty input
require_input() {
    local prompt="$1"
    local var_name="$2"
    local input
    
    read -p "$prompt: " input
    if [ -z "$input" ]; then
        print_error "This field is required"
        exit 1
    fi
    
    eval "$var_name='$input'"
}

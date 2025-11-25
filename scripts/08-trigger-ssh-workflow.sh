#!/bin/bash

# Script to trigger the SSH to VM workflow from local machine
# Usage: ./08-trigger-ssh-workflow.sh

set -e

# Source the library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/library.sh"

# Configuration
WORKFLOW_FILE="04-run-azssh.yml"
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-$(git config user.name)}"
REPO_NAME="azssh-demo"

# Get workflow inputs
print_info "SSH to Private VM - Workflow Trigger"

read -p "Enter runner label (default: self-hosted): " RUNNER_LABEL
RUNNER_LABEL=${RUNNER_LABEL:-self-hosted}

read -p "Enter VM name: " VM_NAME
if [ -z "$VM_NAME" ]; then
    print_error "VM name is required"
    exit 1
fi

read -p "Enter Resource Group name: " RESOURCE_GROUP_NAME
if [ -z "$RESOURCE_GROUP_NAME" ]; then
    print_error "Resource Group name is required"
    exit 1
fi

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# Check if authenticated
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub CLI"
    echo "Run: gh auth login"
    exit 1
fi

# Trigger the workflow
print_info "Triggering workflow..."
gh workflow run "$WORKFLOW_FILE" \
    --ref main \
    -f runner_label="$RUNNER_LABEL" \
    -f vm_name="$VM_NAME" \
    -f resource_group_name="$RESOURCE_GROUP_NAME"

if [ $? -eq 0 ]; then
    print_success "Workflow triggered successfully!"
    echo ""
    print_info "View workflow runs:"
    echo "gh run list --workflow=$WORKFLOW_FILE"
    echo ""
    print_info "Watch the latest run:"
    echo "gh run watch"
else
    print_error "Failed to trigger workflow"
    exit 1
fi

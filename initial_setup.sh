#!/bin/bash

# This script should be run only once, for a fresh setup of the Minecraft server.

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check for required tools
for cmd in gcloud terraform git; do
    if ! command_exists $cmd; then
        echo "Error: $cmd is not installed. Please install it and try again."
        exit 1
    fi
done

# Prompt for project ID
read -p "Enter your GCP project ID: " PROJECT_ID

# Configure gcloud
gcloud config set project $PROJECT_ID

# Enable necessary APIs
echo "Enabling necessary APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable cloudbilling.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable storage-component.googleapis.com

# Set up service account for Terraform
echo "Setting up service account for Terraform..."
gcloud iam service-accounts create terraform --display-name "Terraform Service Account"
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:terraform@$PROJECT_ID.iam.gserviceaccount.com" --role="roles/owner"
gcloud iam service-accounts keys create terraform-key.json --iam-account=terraform@$PROJECT_ID.iam.gserviceaccount.com

# Set GOOGLE_APPLICATION_CREDENTIALS
export GOOGLE_APPLICATION_CREDENTIALS=$(pwd)/terraform-key.json

cd terraform
# Create terraform.tfvars
echo "project_id = \"$PROJECT_ID\"" > terraform.tfvars

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Apply Terraform configuration
echo "Applying Terraform configuration..."
terraform apply -auto-approve

# Get server IP
SERVER_IP=$(terraform output -raw minecraft_server_ip)

echo "Initial setup complete!"
echo "Your Minecraft server IP is: $SERVER_IP"
echo "Crafty Controller will be available at http://$SERVER_IP:8000 in a few minutes."
echo "Please wait 5-10 minutes for the server to fully initialize before accessing Crafty Controller."

cd ..

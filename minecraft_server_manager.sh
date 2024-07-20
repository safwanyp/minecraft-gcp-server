#!/bin/bash

set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Terraform
install_terraform() {
    echo "Installing Terraform..."
    sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl
    curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
    sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
    sudo apt-get update && sudo apt-get install terraform
}

# Function to install Google Cloud SDK
install_gcloud() {
    echo "Installing Google Cloud SDK..."
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
    sudo apt-get update && sudo apt-get install google-cloud-sdk
}

# Check and install required tools
if ! command_exists terraform; then
    echo "Terraform is not installed. Installing..."
    install_terraform
fi

if ! command_exists gcloud; then
    echo "Google Cloud SDK is not installed. Installing..."
    install_gcloud
fi

# Ensure we're logged into Google Cloud
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q "@"; then
    echo "Please login to Google Cloud:"
    gcloud auth login
fi

# Function to set up a new Minecraft server
setup_new_server() {
    echo "Setting up a new Minecraft server..."

    read -p "Enter the GCP project ID: " PROJECT_ID
    read -p "Enter the region (default: us-central1): " REGION
    REGION=${REGION:-us-central1}
    read -p "Enter the zone (default: us-central1-a): " ZONE
    ZONE=${ZONE:-us-central1-a}

    # Set the project
    gcloud config set project $PROJECT_ID

    # Apply Terraform
    echo "Creating infrastructure..."
    cd terraform
    terraform init
    terraform apply -auto-approve -var="project_id=$PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"

    # Get the new server's IP
    SERVER_IP=$(terraform output -raw minecraft_server_ip)

    echo "New Minecraft server is set up at $SERVER_IP"
    echo "Please allow a few minutes for the server to complete its startup process."

    cd ..
}

# Function to migrate an existing Minecraft server
migrate_server() {
    echo "Migrating an existing Minecraft server..."

    read -p "Enter the old GCP project ID: " OLD_PROJECT_ID
    read -p "Enter the new GCP project ID: " NEW_PROJECT_ID
    read -p "Enter the region (default: us-central1): " REGION
    REGION=${REGION:-us-central1}
    read -p "Enter the zone (default: us-central1-a): " ZONE
    ZONE=${ZONE:-us-central1-a}
    read -p "Enter the old server name (default: minecraft-server): " OLD_SERVER_NAME
    OLD_SERVER_NAME=${OLD_SERVER_NAME:-minecraft-server}

    # Set up new infrastructure
    gcloud config set project $NEW_PROJECT_ID
    echo "Creating new infrastructure..."
    cd terraform
    terraform init
    terraform apply -auto-approve -var="project_id=$NEW_PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"

    # Get the new server's IP
    NEW_SERVER_IP=$(terraform output -raw minecraft_server_ip)

    # Run migration script on the old server
    echo "Migrating data to the new server..."
    gcloud config set project $OLD_PROJECT_ID
    gcloud compute ssh $OLD_SERVER_NAME --zone=$ZONE --command="/usr/local/bin/migrate_minecraft.sh $NEW_SERVER_IP"

    # Start Minecraft server on the new instance
    echo "Starting Minecraft server on the new instance..."
    gcloud config set project $NEW_PROJECT_ID
    gcloud compute ssh minecraft-server --zone=$ZONE --command="sudo systemctl start crafty"

    echo "Migration complete! New Minecraft server is running at $NEW_SERVER_IP"
    echo "Don't forget to update your DNS records or inform your players of the new IP address."

    read -p "Do you want to destroy the old infrastructure? (yes/no): " DESTROY_OLD
    if [[ $DESTROY_OLD == "yes" ]]; then
        echo "Destroying old infrastructure..."
        gcloud config set project $OLD_PROJECT_ID
        terraform destroy -auto-approve -var="project_id=$OLD_PROJECT_ID" -var="region=$REGION" -var="zone=$ZONE"
    fi

    cd ..
}

# Main script
echo "Welcome to the Minecraft Server Setup and Migration Script!"
echo "1. Set up a new Minecraft server"
echo "2. Migrate an existing Minecraft server"
read -p "Enter your choice (1 or 2): " CHOICE

case $CHOICE in
    1)
        setup_new_server
        ;;
    2)
        migrate_server
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo "Process completed. Credits to safwanyp hehehe"

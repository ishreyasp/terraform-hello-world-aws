#!/bin/bash

# This script is used to deploy the application to the server
# It will be executed by the user_data of the EC2 instance

# Exit immediately if a command fails
set -e  

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log "Initializing User Data Script..."

# Update the system - Using apt-get with -y and DEBIAN_FRONTEND=noninteractive to avoid prompts
log "Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -y
sudo apt-get upgrade -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"

# Install dependencies
log "Installing required packages..."
log "Installing pre-requisites"
sudo apt-get install -y ca-certificates curl gnupg apt-transport-https
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
log "To install Node.js, run: apt-get install nodejs -y"
sudo apt-get install -y nodejs

# Load environment variables from Terraform
log "Fetching environment variables..."
export PORT="${PORT}"

# Create a non-login user and group for the application
log "Creating user and group nodeapp..."
sudo groupadd nodeapp || true
sudo useradd --no-create-home --shell /usr/sbin/nologin --gid nodeapp nodeapp || true

# Create app directory
log "Creating application directory..."
sudo mkdir -p /opt/nodeapp
cd /opt/nodeapp

# Create app.js using the file content from the local repo
log "Creating app.js..."
cat > /opt/nodeapp/app.js << 'APPJS'
${app_js_content}
APPJS
    
# Create package.json using the file content from the local repo
log "Creating package.json..."
cat > /opt/nodeapp/package.json << 'PKGJSON'
${package_json_content}
PKGJSON

# Create application properties file with environment variables
log "Creating application properties file..."
sudo tee /opt/nodeapp/.env > /dev/null <<EOT
PORT=${PORT}
EOT

# Set permissions
log "Setting permissions..."
sudo chown -R nodeapp:nodeapp /opt/nodeapp
sudo chmod -R 700 /opt/nodeapp

# Install application dependencies
log "Installing application dependencies..."
cd /opt/nodeapp
sudo npm install
sudo chown -R nodeapp:nodeapp /opt/nodeapp

# Create systemd service file
log "Creating systemd service file..."
cat > /etc/systemd/system/nodeapp.service << 'SERVICE'
[Unit]
Description=Node.js Application
After=network.target

[Service]
User=nodeapp
Group=nodeapp
WorkingDirectory=/opt/nodeapp
ExecStart=/usr/bin/node /opt/nodeapp/app.js
EnvironmentFile=/opt/nodeapp/.env
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=nodeapp

[Install]
WantedBy=multi-user.target
SERVICE

# Start SystemD service
log "Reloading systemd daemon..."
sudo systemctl daemon-reload

log "Enabling nodeapp service..."
sudo systemctl enable nodeapp

log "Starting nodeapp service..."
sudo systemctl start nodeapp

log "User Data Script completed successfully."
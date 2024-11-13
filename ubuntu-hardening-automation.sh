#!/bin/bash

# Prompt for the root password
echo "Please enter a new root password:"
read -s root_password

# 1. Change the root password
echo "Changing root password..."
echo "root:$root_password" | sudo chpasswd

# 2. Enable automatic updates with unattended-upgrades
echo "Enabling automatic updates..."
sudo apt update
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# 3. Install Cockpit from the backports repository
echo "Installing Cockpit from backports..."
source /etc/os-release
sudo apt install -y -t ${VERSION_CODENAME}-backports cockpit

# 4. Configure firewall rules

# Change the SSH port to 6969
echo "Changing SSH port to 6969..."
sudo sed -i 's/^#Port 22/Port 6969/' /etc/ssh/sshd_config

# Restart the SSH service to apply the new port
sudo systemctl restart sshd

# Whitelist SSH port 6969
echo "Allowing SSH on port 6969..."
sudo ufw allow 6969/tcp

# Allow port 9090 (for Cockpit access)
echo "Allowing Cockpit on port 9090..."
sudo ufw allow 9090/tcp

# 5. Install and configure Fail2Ban
echo "Installing Fail2Ban..."
sudo apt install -y fail2ban

echo "Configuring Fail2Ban for SSH on port 6969..."
# Create a local Fail2Ban configuration for SSH on custom port
sudo tee /etc/fail2ban/jail.d/custom-ssh.conf > /dev/null <<EOL
[sshd]
enabled = true
port = 6969
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOL

# Restart Fail2Ban to apply the configuration
echo "Restarting Fail2Ban..."
sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

echo "All tasks completed successfully."

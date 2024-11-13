#!/bin/bash

# Enable automatic updates with unattended-upgrades and install Fail2Ban and Cockpit in a single update
echo "Updating system, enabling automatic updates, and installing necessary packages..."
sudo apt update && sudo apt install -y unattended-upgrades fail2ban -t "$(source /etc/os-release && echo ${VERSION_CODENAME}-backports)" cockpit

# Change the SSH port to 6969 and configure the firewall
echo "Configuring SSH on port 6969, setting up firewall rules, and restarting SSH service..."
sudo sed -i 's/^#Port 22/Port 6969/' /etc/ssh/sshd_config
sudo systemctl restart sshd
sudo ufw allow 6969/tcp   # Allow SSH on port 6969
sudo ufw allow 9090/tcp   # Allow Cockpit on port 9090

# Configure Fail2Ban for SSH on custom port 6969
echo "Setting up Fail2Ban to monitor SSH on port 6969..."
sudo tee /etc/fail2ban/jail.d/custom-ssh.conf > /dev/null <<EOL
[sshd]
enabled = true
port = 6969
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOL

# Restart Fail2Ban to apply the configuration
sudo systemctl enable --now fail2ban

echo "Setup completed successfully."

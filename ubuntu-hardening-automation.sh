#!/bin/bash

# Prompt for the root password with input confirmation and ensure it’s non-empty
while true; do
    read -s -p "Please enter a new root password: " root_password
    echo
    if [ -z "$root_password" ]; then
        echo "Password cannot be empty. Please try again."
        continue
    fi
    read -s -p "Confirm the new root password: " root_password_confirm
    echo
    if [ "$root_password" == "$root_password_confirm" ]; then
        echo "Password confirmed."
        break
    else
        echo "Passwords do not match. Please try again."
    fi
done

# Change the root password
echo "Changing root password..."
echo "root:$root_password" | sudo chpasswd || { echo "Failed to change root password"; exit 1; }

# Update system and install packages in one command
echo "Updating system, enabling automatic updates, and installing necessary packages..."
sudo apt update -y && \
sudo apt install -y unattended-upgrades fail2ban cockpit || { echo "Package installation failed"; exit 1; }

# Enable unattended upgrades with no user interaction
sudo dpkg-reconfigure unattended-upgrades || { echo "Failed to configure unattended-upgrades"; exit 1; }

# Configure SSH to use port 6969, and restart SSH service
echo "Configuring SSH on port 6969..."
sudo sed -i '/^#Port 22/c\Port 6969' /etc/ssh/sshd_config
sudo systemctl restart sshd || { echo "Failed to restart SSH"; exit 1; }

# Configure UFW to allow new SSH and Cockpit ports, enabling it without prompt
echo "Configuring firewall rules..."
sudo ufw allow 6969/tcp    # Allow SSH on port 6969
sudo ufw allow 9090/tcp    # Allow Cockpit on port 9090
sudo ufw --force enable || { echo "Failed to enable UFW"; exit 1; }

# Configure Fail2Ban for SSH on custom port 6969
echo "Configuring Fail2Ban for SSH on port 6969..."
sudo tee /etc/fail2ban/jail.d/custom-ssh.conf > /dev/null <<EOL
[sshd]
enabled = true
port = 6969
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
EOL

# Restart and enable Fail2Ban to apply the configuration
sudo systemctl enable --now fail2ban || { echo "Failed to enable Fail2Ban"; exit 1; }

echo "Setup completed successfully."

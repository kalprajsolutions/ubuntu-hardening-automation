#!/usr/bin/env bash
###############################################################################
# Ubuntu (22.04 +) hardening with a strict UFW policy
# – Automatic security updates
# – SSH on custom port (6969) + root/password auth allowed
# – Fail2Ban
# – Only essential service ports opened; everything else denied
###############################################################################
set -Eeuo pipefail
IFS=$'\n\t'

##### ─────────────── CONFIGURABLE VARIABLES ─────────────── #####
SSH_PORT=6969             # Custom SSH port
ALLOW_ROOT_SSH="yes"      # PermitRootLogin (yes|no)
ALLOW_PASSWORD_AUTH="yes" # PasswordAuthentication (yes|no)
F2B_MAXRETRY=5            # Fail2Ban retry limit

# List of TCP ports that must remain open
# (Add or remove ports as needed, separated by spaces)
ALLOWED_TCP_PORTS=(
  80     # HTTP
  20     # FTP-DATA (ftp servers often also need 21 – add if required)
  22     # Default SSH (keep if another host/device still connects on 22)
  25     # SMTP
  443    # HTTPS
  7080   # Custom / reverse-proxy
  6969   # Custom SSH
  83     # DNS?
)
#################################################################

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)"; exit 1; }

echo "1️⃣  Updating system & installing base packages ..."
apt-get update -qq
apt-get -y dist-upgrade
apt-get -y install --no-install-recommends \
    ufw fail2ban unattended-upgrades cron

echo "2️⃣  Enabling unattended security upgrades ..."
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade   "1";
APT::Periodic::AutocleanInterval    "7";
EOF
dpkg-reconfigure --frontend=noninteractive unattended-upgrades

echo "3️⃣  Hardening SSH (port $SSH_PORT) ..."
sed -ri \
  -e "s/^#?Port .*/Port ${SSH_PORT}/" \
  -e "s/^#?PermitRootLogin .*/PermitRootLogin ${ALLOW_ROOT_SSH}/" \
  -e "s/^#?PasswordAuthentication .*/PasswordAuthentication ${ALLOW_PASSWORD_AUTH}/" \
  /etc/ssh/sshd_config
systemctl reload sshd

echo "4️⃣  Configuring a strict UFW firewall ..."
ufw --force reset               # start from a clean slate
ufw default deny incoming
ufw default allow outgoing

for p in "${ALLOWED_TCP_PORTS[@]}"; do
  ufw allow "${p}/tcp" comment "open port ${p}"
done

ufw --force enable
echo "   ➜ Allowed TCP ports: ${ALLOWED_TCP_PORTS[*]}"

echo "5️⃣  Setting up Fail2Ban ..."
cat >/etc/fail2ban/jail.d/sshd-local.conf <<EOF
[sshd]
enabled   = true
port      = ${SSH_PORT}
logpath   = %(sshd_log)s
maxretry  = ${F2B_MAXRETRY}
bantime   = 1h
findtime  = 15m
EOF
systemctl enable --now fail2ban

echo "6️⃣  Basic kernel/network hardening ..."
timedatectl set-ntp true
printf "net.ipv4.conf.all.accept_redirects=0\nnet.ipv6.conf.all.accept_redirects=0\nkernel.randomize_va_space=2\n" >/etc/sysctl.d/99-hardening.conf
sysctl --system >/dev/null

echo -e "\n✅  Hardened with strict firewall.\nOpen ports: ${ALLOWED_TCP_PORTS[*]}"

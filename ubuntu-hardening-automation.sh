#!/usr/bin/env bash
###############################################################################
# Ubuntu (22.04 +) hardening with a strict UFW policy
# – Automatic security updates
# – SSH on custom port (6969) + root/password auth allowed
# – Fail2Ban
# – IPv4-only
# – Only essential service ports opened; everything else denied
###############################################################################
set -Eeuo pipefail
IFS=$'\n\t'

##### ────────────── CONFIG — EDIT AS NEEDED ────────────── #####
SSH_PORT=6969             # Custom SSH port
ALLOW_ROOT_SSH="yes"      # PermitRootLogin  (yes|no)
ALLOW_PASSWORD_AUTH="yes" # PasswordAuthentication (yes|no)
F2B_MAXRETRY=5            # Fail2Ban retry limit

# List ONLY the inbound TCP ports you **really** need
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
#############################################################

[[ $EUID -eq 0 ]] || { echo "Run as root (sudo)"; exit 1; }

echo "1️⃣  System update & base packages ..."
apt-get update -qq
apt-get -y dist-upgrade
apt-get -y install --no-install-recommends ufw fail2ban unattended-upgrades cron

echo "2️⃣  Unattended upgrades ..."
cat >/etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade   "1";
APT::Periodic::AutocleanInterval    "7";
EOF
dpkg-reconfigure --frontend=noninteractive unattended-upgrades

echo "3️⃣  Disable IPv6 completely ..."
# Runtime (immediate)
sysctl -qw net.ipv6.conf.all.disable_ipv6=1
sysctl -qw net.ipv6.conf.default.disable_ipv6=1
# Persist after reboot
cat >/etc/sysctl.d/60-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
# Make sure UFW doesn’t re-enable it
sed -ri 's/^IPV6=.*/IPV6=no/' /etc/default/ufw

echo "4️⃣  SSH hardening (port $SSH_PORT) ..."
sed -ri \
  -e "s/^#?Port .*/Port ${SSH_PORT}/" \
  -e "s/^#?PermitRootLogin .*/PermitRootLogin ${ALLOW_ROOT_SSH}/" \
  -e "s/^#?PasswordAuthentication .*/PasswordAuthentication ${ALLOW_PASSWORD_AUTH}/" \
  /etc/ssh/sshd_config
systemctl reload sshd

echo "5️⃣  Strict IPv4-only UFW ..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
for p in "${ALLOWED_TCP_PORTS[@]}"; do
  ufw allow "${p}/tcp" comment "open port ${p}"
done
ufw --force enable
echo "   ➜ Allowed ports: ${ALLOWED_TCP_PORTS[*]}"

echo "6️⃣  Fail2Ban ..."
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

echo "7️⃣  Extra kernel tweaks ..."
timedatectl set-ntp true
cat >/etc/sysctl.d/99-hardening.conf <<'EOF'
net.ipv4.conf.all.accept_redirects = 0
kernel.randomize_va_space          = 2
EOF
sysctl --system >/dev/null

echo "Change TImezone to Asia Kolkata"
timedatectl set-timezone Asia/Kolkata

echo -e "\n✅  Hardened, IPv6 disabled. Inbound IPv4 ports open: ${ALLOWED_TCP_PORTS[*]}"

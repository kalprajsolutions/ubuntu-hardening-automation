#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  OpenLiteSpeed one-shot installer + vhost bootstrapper
#
#  Usage examples:
#     sudo ./ols-autoinstall.sh example.com
#     sudo ./ols-autoinstall.sh --admin-pass MySecretP@ss site.example
#
#  Re-run on an existing box: the script is idempotent – it only patches what
#  is missing or different.
# ---------------------------------------------------------------------------

set -euo pipefail
trap 'echo -e "\n❌  Error on line $LINENO. Abort." >&2' ERR

##############################################################################
#  Helpers
##############################################################################
log() { printf '\n\033[1;32m→ %s\033[0m\n' "$*"; }

random_pass() { tr -dc 'A-Za-z0-9@#%^+=' </dev/urandom | head -c16; }

# update_or_add <file> <directive_name> <replacement_line>
update_or_add() {
  local file="$1" key="$2" new="$3"
  if grep -qE "^[[:space:]]*${key}[[:space:]]" "$file"; then
      sed -i "s|^[[:space:]]*${key}[[:space:]].*|${new}|" "$file"
  else
      printf '%s\n' "$new" >>"$file"
  fi
}

##############################################################################
#  CLI args
##############################################################################
ADMIN_EMAIL="pushkraj@kalprajsolutions.com"
ADMIN_PASS=""
POSITIONAL=()
OLD_DOMAIN="rknrd-218.kalprajsolutions.net" 

while [[ $# -gt 0 ]]; do
  case "$1" in
    --admin-pass)
        ADMIN_PASS="$2"; shift 2;;
    --admin-email)
        ADMIN_EMAIL="$2"; shift 2;;
    -*)
        echo "Unknown flag $1"; exit 1;;
     *)
        POSITIONAL+=("$1"); shift;;
  esac
done
set -- "${POSITIONAL[@]:-}"

[[ $# -eq 1 ]] || { echo "Usage: $0 [--admin-pass xxx] [--admin-email foo@bar] <domain>" >&2; exit 1; }
DOMAIN="$1"

# rudimentary domain check
[[ $DOMAIN =~ ^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]] || { echo "Invalid domain: $DOMAIN"; exit 1; }

[[ -z $ADMIN_PASS ]] && ADMIN_PASS=$(random_pass)

log "Installing prerequisites"
apt-get -qq update
DEBIAN_FRONTEND=noninteractive apt-get -qq install -y curl unzip lsb-release

##############################################################################
# 1. Install / upgrade OpenLiteSpeed
##############################################################################
if ! command -v lswsctrl >/dev/null; then
  log "Installing OpenLiteSpeed + LS-PHP 8.0"
  bash <(curl -fsSL https://raw.githubusercontent.com/litespeedtech/ols1clk/master/ols1clk.sh) \
       -A "${ADMIN_PASS}" --email "${ADMIN_EMAIL}" --lsphp 80 --quiet
else
  log "OpenLiteSpeed already present – skipping base install"
fi

##############################################################################
# 4. Create / refresh virtual host
##############################################################################
log "Creating virtual host for ${DOMAIN}"
/bin/bash <(curl -fsSL https://raw.githubusercontent.com/litespeedtech/ls-cloud-image/master/Setup/vhsetup.sh) \
     -d "${DOMAIN}" -le "${ADMIN_EMAIL}" -f

##############################################################################
# 5. Deploy site content
##############################################################################
VHOST_CONF="/usr/local/lsws/conf/vhosts/${DOMAIN}/vhconf.conf"
DOCROOT=$(awk '$1=="docRoot"{print $2}' "$VHOST_CONF")

log "Deploying website files to ${DOCROOT}"
shopt -s dotglob  # include hidden files in wildcard
rm -rf "${DOCROOT:?}"/*
curl -fsSL -o /tmp/site.zip "https://raw.githubusercontent.com/Pushkraj19/regular-files/master/website.zip"
unzip -P "kalprajsolutions.com" -q /tmp/site.zip -d "${DOCROOT}"


# Escape slashes in $DOMAIN in case someone passes a URL
SAFE_DOMAIN=${DOMAIN//\//\\/}
SAFE_OLD=${OLD_DOMAIN//\//\\/}

find "${DOCROOT}/sites" -type f -name '*.php' -print0 \
  | xargs -0 sed -i "s/${SAFE_OLD}/${SAFE_DOMAIN}/g"

##############################################################################
# 2. Secure admin panel to localhost
##############################################################################
ADMIN_CONF=/usr/local/lsws/admin/conf/admin_config.conf
log "Locking admin panel to 127.0.0.1:7080"
update_or_add "$ADMIN_CONF" 'address' 'address                  127.0.0.1:7080'

##############################################################################
# 3. Global server tuning
##############################################################################
HTTPD_CONF=/usr/local/lsws/conf/httpd_config.conf
log "Applying global tweaks"

update_or_add "$HTTPD_CONF" 'adminEmails'    "adminEmails              ${ADMIN_EMAIL}"
update_or_add "$HTTPD_CONF" 'maxConns'       'maxConns                 100'           # inside wsgiDefaults
update_or_add "$HTTPD_CONF" 'quicEnable'     'quicEnable              1'
update_or_add "$HTTPD_CONF" 'quicShmDir'     'quicShmDir /dev/shm'
update_or_add "$HTTPD_CONF" 'indexFiles'     'indexFiles           index.html, index.php'
update_or_add "$HTTPD_CONF" 'autoIndex'      'autoIndex             0'

##############################################################################
# 6. Reload OLS
##############################################################################
log "Reloading OpenLiteSpeed"
if ! /usr/local/lsws/bin/lswsctrl reload; then
  /usr/local/lsws/bin/lswsctrl restart
fi

##############################################################################
# 7. Recap
##############################################################################
cat <<EOF

=======================================================================
 ✔  ${DOMAIN} is live
 ✔  Admin GUI locked to https://127.0.0.1:7080
 ✔  Admin credentials:
        user: admin
        pass: ${ADMIN_PASS}
=======================================================================
EOF

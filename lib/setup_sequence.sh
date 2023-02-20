#!/bin/bash -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#####
# NAME
#   setup_sequence.sh
# DESCRIPTION
#   Run the Setup Sequence to configure a debian pc from scratch.
# USAGE
#   setup_sequence.sh STARTING_POINT
# PARAMETERS
#   STARTING_POINT may be one of the following:
#     1   Initial Starting point
#     2   Post SSH Port Change
#####

#check root
if [[ $EUID != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

### LOCALS ###
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SUDOERS_FILE="/etc/sudoers.d/$ADMIN_USERNAME"NOPASSWORD
PASSWORD_CONFIG_FILE="/etc/pam.d/common-password"
UNATTENDED_10PERIODIC_CONF=/etc/apt/apt.conf.d/10periodic
UNATTENDED_50UNATTENDED_CONF=/etc/apt/apt.conf.d/50unattended-upgrades
# MAILUTILS_CONF=/etc/mailutils.conf
FAIL2BAN_JAIL_LOCAL=/etc/fail2ban/jail.local
ACME_CHALLENGE_PATH=/var/lib/letsencrypt
SSL_NGINX_TEMPLATE=$SCRIPT_DIR/template_ssl.conf
LE_ACME_NGINX_TEMPLATE=$SCRIPT_DIR/template_letsencrypt.conf

START_AT="${1:0}"

if (( START_AT <= 1 )); then
  updateSystem
  setPasswordRequirements "$PASSWORD_CONFIG_FILE"
  setAdminUser "$ADMIN_USERNAME" "$ADMIN_USER_HOME"
  setSudoerAllowed "$ADMIN_USERNAME" "$SUDOERS_FILE"
  setPermissions "$ADMIN_USERNAME:$ADMIN_USERNAME" "u=rwx,g=rX,o-rwx" "/setup"
  disableIPv6 "$SSH_CONFIG_FILE"
  setSSHPort "$SSH_CONFIG_FILE" "$SSH_PORT"
  setSSHUsers "$SSH_CONFIG_FILE" "$ADMIN_USERNAME"
  setLogwatch "$MY_EMAIL_ADDRESS"
  setFirewall "$SSH_PORT"

  echo
  echo "SSH will now be disconnected as the process restarts. New SSH port is: $SSH_PORT"

  service ssh restart

fi

if (( START_AT <= 2 )); then
  disableRootLogin "$SSH_CONFIG_FILE"
  setSSHFirewall
  setHostname "$SERVER_HOSTNAME.$SERVER_DOMAIN"
  setEmail "$SERVER_EMAIL_DOMAIN" "$SMTP_RELAY_DOMAIN" "$SMTP_RELAY_PORT" "$SMTP_RELAY_USERNAME" "$SMTP_PASSWORD"
  setUnattendedUpgrades "$UNATTENDED_10PERIODIC_CONF" "$UNATTENDED_50UNATTENDED_CONF" "$MY_EMAIL_ADDRESS"
  setNginx
  setSSL "$ACME_CHALLENGE_PATH" "$SSL_NGINX_TEMPLATE" "$LE_ACME_NGINX_TEMPLATE" "$SERVER_HOSTNAME.$SERVER_DOMAIN"
  setFail2ban "$FAIL2BAN_JAIL_LOCAL" "$SSH_PORT"

  apt-get -yq autoremove
  rm -f "$SUDOERS_FILE"
fi
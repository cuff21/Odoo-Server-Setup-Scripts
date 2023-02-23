#!/bin/bash -e

usage() {
cat << EndHelp
Run a preconfigured setup sequence to secure a debian pc from initial boot.

Usage: 
  ${0##*/} [-s START_POINT] -c CONFIG_FILE

Options:
  -s START_POINT, --start START_POINT   Select the starting point of the configuration sequence
                                          START_POINT May be one of the following:
                                            1   Beginning of sequence (for blank server)
                                            2   After initial system update/upgrade
                                            3   Resume sequence after SSH Port Change
                                            4   Prior to Clean-up
  -c CONFIG_FILE, --config CONFIG_FILE  The user configuration file

EndHelp
}

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# CHECK FOR ROOT #
if [[ $EUID != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

### PARSE ARGUMENTS ###
START_AT=0
CONFIG_FILE=""

if ! VALID_ARGS=$(getopt -o c:s: --long config:,start: -- "$@")
then
  # getopt will output an error message, just exit
  exit 1;
fi

set -- "$VALID_ARGS"
while [ $# -gt 0 ]; do
  #consume first arg
  case "$1" in
    -c | --config) CONFIG_FILE="$2" ; shift 2 ;;
    -s | --start) START_AT="$2"  ; shift 2 ;;
    --) shift ; break ;;
    -*) usage
  esac
done
: "${CONFIG_FILE:?A user configuration file is required.}"

### Load Functions ###
. "$SCRIPT_DIR/config_funcs.shlib"
. "$SCRIPT_DIR/setup_funcs.shlib"

### Load Config ###
config_load "$CONFIG_FILE"

### Evaluate Templates ###
#TODO: evaluate templates before sequence instead of within functions

# Update
if (( START_AT <= 1 )); then
  updateSystem
fi

# SSH as root
if (( START_AT <= 2 )); then
  setPasswordRequirements 
  setAdminUser "$ADMIN_USERNAME"
  sudoRequirePassword "$ADMIN_USERNAME" false
  setPermissions "$ADMIN_USERNAME" "$ADMIN_USERNAME" "u=rwx,g=rX,o-rwx" "/setup"
  disableIPv6
  setSSHPort "$SSH_PORT"
  setSSHUser "$ADMIN_USERNAME"
  setLogwatch
  setFirewall "$SSH_PORT"

  echo
  echo "SSH will now be disconnected as the process restarts. 
        New SSH port is: $SSH_PORT SSH user is: $ADMIN_USERNAME"
  service ssh restart
fi

# SSH as ADMIN_USER
if (( START_AT <= 3 )); then
  echo "Successful login with $ADMIN_USERNAME! Disabling root login."
  disableRootLogin
  setSSHFirewall
  hostnamectl set-hostname "$SERVER_HOSTNAME.$SERVER_DOMAIN"
  setEmailRelay "$SERVER_EMAIL_DOMAIN" "$SMTP_RELAY_DOMAIN" "$SMTP_RELAY_PORT" "$SMTP_RELAY_USERNAME" "$SMTP_RELAY_PASSWORD"
  echo "This is a test of the server email setup." | mail -s "Server Mail Test" -aFrom:"$SERVER_AUTOMAIL_ADDRESS" "$MY_EMAIL_ADDRESS"
  
  setUnattendedUpgrades "$MY_EMAIL_ADDRESS"
  setNginx 

  setSSL "$ACME_CHALLENGE_PATH" "$NGINX_ACME_SNIPPET_PATH" "$NGINX_SSL_SNIPPET_PATH"\
         "$SERVER_HOSTNAME.$SERVER_DOMAIN" "$MY_EMAIL_ADDRESS" 
  setFail2ban
fi

# Cleanup
if (( START_AT <= 4 )); then
  apt-get -yq autoremove
  sudoRequirePassword "$ADMIN_USERNAME" true
fi
#!/bin/bash -e
set -u

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#LOAD CONFIG VARIABLES
. "$SCRIPT_DIR/CONFIG.env"

#Internal Variables
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SUDOERS_FILE="/etc/sudoers.d/$ADMIN_USERNAME"NOPASSWORD
PASSWORD_CONFIG_FILE="/etc/pam.d/common-password"

echo "Updating System"
apt-get -yq -q update && apt-get -yq upgrade
apt-get -yq dist-upgrade
apt-get -yq install sudo
apt-get -yq autoremove

#Enable password complexity requirements
apt-get -yq install libpam-cracklib

if grep -Fxq "pam_cracklib" "$PASSWORD_CONFIG_FILE"; then
  echo "Password requirements already set."
else
  echo "password        requisite                       pam_cracklib.so retry=3 minlen=8 difok=3" >> "$PASSWORD_CONFIG_FILE"
fi

#setup admin user
if id "$ADMIN_USERNAME" &>/dev/null; then
    echo "$ADMIN_USERNAME user already exists."
else
    echo "Adding $ADMIN_USERNAME user account."
    echo
    echo "Please set a password for your new Admin account ('$ADMIN_USERNAME'):"
    echo
    adduser --gecos '' "$ADMIN_USERNAME"
    usermod -a -G sudo "$ADMIN_USERNAME"
    ADMIN_USER_HOME=$(eval echo "~$ADMIN_USERNAME")
    
    echo "Admin user home folder: $ADMIN_USER_HOME"
    sudo -u "$ADMIN_USERNAME" ssh-keygen -q -N "" -f "$ADMIN_USER_HOME/.ssh/id_rsa" 
    
    chown "$ADMIN_USERNAME" "$ADMIN_USER_HOME/.ssh"
    chmod 0700 "$ADMIN_USER_HOME/.ssh"
    touch "$ADMIN_USER_HOME/.ssh/authorized_keys"
    chown "$ADMIN_USERNAME" "$ADMIN_USER_HOME/.ssh/authorized_keys"
    chmod 0600 "$ADMIN_USER_HOME/.ssh/authorized_keys"

fi

#disable sudoers warning

mkdir -p "/var/lib/sudo/lectured" && touch "/var/lib/sudo/lectured/$ADMIN_USERNAME"

#Disable sudo password for admin user (for step 2 installation)
echo "$ADMIN_USER ALL=(ALL:ALL) NOPASSWD: ALL" | tee "$SUDOERS_FILE"

# if [[ -f "$SUDOERS_FILE" ]]; then
#   sed -i '/^#Defaults.*lecture.*$/s/^#//' "$SUDOERS_FILE"
#   sed -i '/^Defaults.*lecture[[:blank:]]*=.*/s/lecture[[:blank:]]*=[[:blank:]]*\w\w*/lecture = never/' "$SUDOERS_FILE"

# else
#   echo "Defaults        lecture = never" > "$SUDOERS_FILE"
# fi

#enable admin access to setup files
chgrp -R "$ADMIN_USERNAME" "/setup"
chmod -R u=rwx,g=rX,o-rwx "/setup"

#disable ipv6
sed -i '/^#AddressFamily .*$/s/^#//' "$SSH_CONFIG_FILE"
sed -i '/^AddressFamily/s/ .*/ inet/' "$SSH_CONFIG_FILE"

#change port
sed -i '/^#Port 22$/s/^#//' "$SSH_CONFIG_FILE"
sed -i '/^Port 22$/s/ 22/ '"$SSH_PORT"'/' "$SSH_CONFIG_FILE"

#restrict SSH users
if grep -Fxq "AllowUsers" "$SSH_CONFIG_FILE"; then
  sed -i '/^#AllowUsers .*$/s/^#//' "$SSH_CONFIG_FILE"
  sed -i '/^AllowUsers/s/ .*/ '"$ADMIN_USERNAME"'/' "$SSH_CONFIG_FILE"
else
  echo "AllowUsers $ADMIN_USERNAME" >> "$SSH_CONFIG_FILE"
fi

#LOG MANAGEMENT
echo
echo "Installing Logwatch/Logrotate"

apt-get -yq install logwatch logrotate
tee /etc/cron.daily/00logwatch <<<"/usr/sbin/logwatch --output mail --mailto $MY_EMAIL_ADDRESS --detail high"

service logwatch restart

#Firewall
echo "Initializing firewall"
apt-get -yq install ufw
ufw allow ssh
ufw allow dns
ufw allow "$SSH_PORT/tcp"

ufw --force enable

#restarting SSH
echo
echo "SSH will now be disconnected as the process restarts."
echo 'PLEASE RECONNECT USING ssh '"$ADMIN_USERNAME"'@[server.url.address] -p '"$SSH_PORT"


service ssh restart
#reboot now


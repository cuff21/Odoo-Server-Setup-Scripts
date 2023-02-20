#!/bin/bash -e
set -u

#TODO: Move to setup_functions

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#LOAD CONFIG VARIABLES
. "$SCRIPT_DIR/CONFIG.env"
. "$SCRIPT_DIR/helper_functions.sh"

#Local variables
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
SUDOERS_FILE="/etc/sudoers.d/$ADMIN_USERNAME"NOPASSWORD
UNATTENDED_10PERIODIC_CONF=/etc/apt/apt.conf.d/10periodic
UNATTENDED_50UNATTENDED_CONF=/etc/apt/apt.conf.d/50unattended-upgrades
# MAILUTILS_CONF=/etc/mailutils.conf
FAIL2BAN_JAIL_LOCAL=/etc/fail2ban/jail.local
ACME_CHALLENGE_PATH=/var/lib/letsencrypt
SSL_NGINX_TEMPLATE=$SCRIPT_DIR/template_ssl.conf
LE_ACME_NGINX_TEMPLATE=$SCRIPT_DIR/template_letsencrypt.conf


#check root
if [[ $EUID != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi


echo "Successful login with $ADMIN_USERNAME! Disabling root login."
#disable Root Login
sed -i '/^PermitRootLogin/s/ .*/ no/' "$SSH_CONFIG_FILE"

echo "Please create an SSH Key and disable password login for optimal security"
##disable password login
#sed -i '/^PasswordAuthentication/s/ .*/ no/' "$SSH_CONFIG_FILE"

#FIREWALL
echo "Removing default SSH Port firewall rule"
ufw delete allow ssh
service ufw restart

#HOSTNAME
echo "Changing server hostname"
hostnamectl set-hostname "$SERVER_HOSTNAME.$SERVER_DOMAIN"

#EMAIL
echo "Configuring Email"
apt-get -yq install mailutils

tee "/etc/mailutils.conf" <<EndOfMessage
address{
    email-domain $SERVER_EMAIL_DOMAIN;
};
EndOfMessage

debconf-set-selections <<< "postfix postfix/mailname string $SERVER_EMAIL_DOMAIN"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
apt-get install --assume-yes postfix 
apt-get install libsasl2-modules -y

#TODO: I think this is removing some existing configuration?
postconf -e "smtp_sasl_auth_enable = yes"
postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
postconf -e "smtp_sasl_security_options = noanonymous"
postconf -e "smtp_sasl_tls_security_options = noanonymous"
postconf -e "smtp_tls_security_level = encrypt"
postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"
postconf -e "header_size_limit = 4096000"
postconf -e "relayhost = [$SMTP_RELAY_DOMAIN]:$SMTP_RELAY_PORT"
postconf -e "myhostname = $SERVER_EMAIL_DOMAIN"
postconf -e "alias_maps = hash:/etc/aliases"

#prompt for password
echo "[$SMTP_RELAY_DOMAIN]:$SMTP_RELAY_PORT $SMTP_RELAY_USERNAME:$SMTP_RELAY_PASSWORD" > "/etc/postfix/sasl_passwd"

#secure password
postmap /etc/postfix/sasl_passwd
chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl/sasl_passwd.db
chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl/sasl_passwd.db
systemctl restart postfix

# tee "$MAILUTILS_CONF" <<EndOfMessage
# address {
#     email-domain $SERVER_EMAIL_DOMAIN;
# };
# EndOfMessage

echo "This is a test of the server email setup." | mail -s "Server Mail Test" -aFrom:"$SERVER_AUTOMAIL_ADDRESS" "$MY_EMAIL_ADDRESS"

#UNATTENDED UPGRADES
echo "Configuring Unattended Security Upgrades"
apt-get update && apt-get -yq upgrade
apt-get -yq install unattended-upgrades apt-config-auto-update

systemctl enable unattended-upgrades

tee "$UNATTENDED_10PERIODIC_CONF" <<'EndOfMessage'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";
EndOfMessage

tee "$UNATTENDED_50UNATTENDED_CONF" <<'EndOfMessage'
Unattended-Upgrade::Allowed-Origins {
"${distro_id}:${distro_codename}";
"${distro_id}:${distro_codename}-security";
"${distro_id}ESMApps:${distro_codename}-apps-security";
"${distro_id}ESM:${distro_codename}-infra-security";
//"${distro_id}:${distro_codename}-updates";
};
Unattended-Upgrade::Automatic-Reboot "true";
EndOfMessage

tee -a "$UNATTENDED_50UNATTENDED_CONF" < "Unattended-Upgrade::Mail \"$MY_EMAIL_ADDRESS\";"

sed -i '/^email_address=/s/.*/'"$MY_EMAIL_ADDRESS"'/' "/etc/apt/listchanges.conf"

systemctl restart unattended-upgrades


#nginx
apt-get -yq install nginx
ufw allow 'Nginx Full'
systemctl enable nginx


#SSL
# letsencrypt setup
apt-get -y install certbot

## Not required if only using TLS 1.3
# echo
# echo "generating a secure SSL key. This may take a couple of minutes..."
# openssl dhparam -out $NGINX_SSL_DHPARAM_PATH 2048
echo "Creating ACME challenge folder"
mkdir -p "$ACME_CHALLENGE_PATH/.well-known"
chgrp www-data "$ACME_CHALLENGE_PATH"
chmod g+s "$ACME_CHALLENGE_PATH"


# Copy ssl.conf, letsencrypt.conf to snippets
echo "Copying NGINX snippet templates"
evalConfigTemplate < "$SSL_NGINX_TEMPLATE" > /etc/nginx/snippets/ssl.conf
evalConfigTemplate < "$LE_ACME_NGINX_TEMPLATE" > /etc/nginx/snippets/letsencrypt.conf


# Create temp nginx config if it doesn't exist
echo "Configuring nginx to pass SSL domain verification"
nginx_temp=0
NGINX_TEMP_SERVER="$SERVER_HOSTNAME.$SERVER_DOMAIN"
NGINX_AVAIL_PATH="/etc/nginx/sites-available"
NGINX_ENABLE_PATH="/etc/nginx/sites-enabled"
if [[ ! -f "$NGINX_AVAIL_PATH/$NGINX_TEMP_SERVER.conf" ]]; then
    nginx_temp=1
    #Temporary nginx conf
    cat << EOF_NGINX > "$NGINX_AVAIL_PATH/$NGINX_TEMP_SERVER.conf"
server {
    listen 80;
    server_name $NGINX_TEMP_SERVER;
    include snippets/letsencrypt.conf;
}

EOF_NGINX

    ln -s "$NGINX_AVAIL_PATH/$NGINX_TEMP_SERVER.conf" "$NGINX_ENABLE_PATH/"
    systemctl restart nginx 
fi

# run certbot
echo "Aqcuiring certificate"
certbot certonly -n --agree-tos --email "$MY_EMAIL_ADDRESS" --webroot -w "$ACME_CHALLENGE_PATH" -d "$SERVER_HOSTNAME.$SERVER_DOMAIN"
grep -qF -- "deploy-hook = systemctl reload nginx" "/etc/letsencrypt/cli.ini" || echo " deploy-hook = systemctl reload nginx" >> "/etc/letsencrypt/cli.ini"

# clean up temp 
if [[ nginx_temp -eq 1 ]]; then
    echo "Cleaning up nginx temp configs"
    rm "$NGINX_ENABLE_PATH/$NGINX_TEMP_SERVER.conf"
    rm "$NGINX_AVAIL_PATH/$NGINX_TEMP_SERVER.conf"
fi
systemctl restart nginx

#fail2ban
echo "Initializing fail2ban"
apt-get -yq install fail2ban

#only copy default if local jail does not exist
test -f "$FAIL2BAN_JAIL_LOCAL" || cp /etc/fail2ban/jail.conf "$FAIL2BAN_JAIL_LOCAL"

sed -i "s/banaction[[:blank:]]*=.*/banaction = ufw/" "$FAIL2BAN_JAIL_LOCAL"
sed -i "/^\[sshd\]$/,/^\[/s/port[[:blank:]]*=.*/port = ssh,$SSH_PORT/" "$FAIL2BAN_JAIL_LOCAL"


service fail2ban restart

# #GIT
# echo
# echo "Installing GIT"

# apt-get -yq install git

# #DOCKER
# echo
# echo "Installing Docker"
# apt-get -yq install apt-transport-https ca-certificates curl software-properties-common
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
# add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"

# apt install docker-ce docker-compose -y
# usermod -aG docker $ADMIN_USERNAME

# service docker start

#Testing


echo "Cleaning up"
apt-get -yq autoremove
rm -f "$SUDOERS_FILE"

echo
echo "Step 2 is complete."
echo

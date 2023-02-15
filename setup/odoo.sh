#!/bin/bash -e
set -u

#check root
if [[ $EUID != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#LOAD CONFIG VARIABLES
. "$SCRIPT_DIR/CONFIG.env"

#LOAD HELPER FUNCTIONS
. "$SCRIPT_DIR/helper_functions.sh"

#SOURCES
WKHTMLTOPDF_SOURCE='https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.buster_amd64.deb'
WKHTMLTOPDF_BINARY='wkhtmltox_0.12.5-1.buster_amd64.deb'

#INTERNAL VARIABLES
ODOO_NGINX_CONF_PATH=/etc/nginx/sites-available/$SERVER_HOSTNAME.$SERVER_DOMAIN.conf
ODOO_SYSTEMD_PATH=/etc/systemd/system/$ODOO_SERVICE_NAME.service
ODOO_CONF_BACKUP=$ODOO_CONF_PATH.bak
ODOO_CONF_TEMPLATE=$SCRIPT_DIR/template_odoo.conf
ODOO_NGINX_TEMPLATE=$SCRIPT_DIR/template_odoo_nginx.conf
ODOO_SYSTEMD_TEMPLATE=$SCRIPT_DIR/template_systemd.service


# apt-get update && apt-get -yq install gnupg

# #REPOSITORIES
# echo "Adding Odoo repository"
# ODOO_REPOKEY="$(wget -O - https://nightly.odoo.com/odoo.key)"
# echo "$ODOO_REPOKEY" | gpg --dearmor | sudo tee /usr/share/keyrings/odoo-archive-keyring.gpg | gpg --armor
# echo "deb http://nightly.odoo.com/15.0/nightly/deb/ ./" > /etc/apt/sources.list.d/odoo.list

# #PREREQUISITES
# echo "Updating new repo.."
apt-get update

echo "Installing prerequisites"
apt-get install git python3 python3-pip wget python3-venv python3-wheel python3-setuptools libldap2-dev libpq-dev libsasl2-dev -y

# # python pip update
# python3 -m pip install --upgrade pip setuptools wheel

# Creating System User
sudo useradd -m -d "/opt/$ODOO_SYSTEM_USERNAME" -U -r -s /bin/bash "$ODOO_SYSTEM_USERNAME"

# wkhtmltopdf (version in debian Buster repo does not support headers and footers)
wget "$WKHTMLTOPDF_SOURCE"
apt install "./$WKHTMLTOPDF_BINARY"

# Create Installation directory
mkdir -p "$ODOO_INSTALL_PARENT_PATH"

# Log directories
mkdir "$ODOO_LOGPATH"
chown "$ODOO_SYSTEM_USERNAME":"$ODOO_SYSTEM_USERNAME" "$ODOO_LOGPATH"
chmod 777 "$ODOO_LOGPATH"

# cloning repo
git clone "$ODOO_REPO" --depth 1 --branch "$ODOO_REPO_BRANCH" --single-branch "$ODOO_INSTALL_ROOT_PATH"

# Set permissions
chown -R "$ODOO_SYSTEM_USERNAME:$ODOO_SYSTEM_USERNAME" "$ODOO_INSTALL_ROOT_PATH"

# TODO: Postgres
apt-get install postgresql postgresql-client -y
sudo -u postgres -c "createuser -s $ODOO_SYSTEM_USERNAME"

## MAIN APP REPO VERSION
#apt-get install odoo -y

#RUN AS ODOO USER
sudo -u "$ODOO_SYSTEM_USERNAME" <<USERCMDS

    # Create postgres DB
    createdb "$ODOO_SYSTEM_USERNAME"

    # Setup Python virtual environment
    python3 -m venv "$ODOO_INSTALL_ROOT_PATH/odoo-venv"
    source "$ODOO_INSTALL_ROOT_PATH/odoo-venv/bin/activate"

    # Install Python dependencies
    pip3 install wheel
    pip3 install -r "$ODOO_INSTALL_ROOT_PATH/requirements.txt"

    # xlwt for xls export (not in debian Bullseye)
    pip3 install xlwt

    # num2words for textual amounts
    pip3 install num2words

    deactivate

USERCMDS

# Add-on Installation
mkdir -p "$ODOO_ADDON_PATH"
#  TODO: Add Odoo Addons

#CONFIGURATION
# crudini for automated Odoo config ini file merge
apt-get -yq install crudini

mv -f "$ODOO_CONF_PATH" "$ODOO_CONF_BACKUP" >&2 /dev/null ||
crudini --merge --output=- "$ODOO_CONF_BACKUP" < "$ODOO_CONF_TEMPLATE" | evalConfigTemplate > "$ODOO_CONF_PATH"

#Nginx config
evalConfigTemplate < "$ODOO_NGINX_TEMPLATE" > "$ODOO_NGINX_CONF_PATH"
ln -sf "$ODOO_NGINX_CONF_PATH" /etc/nginx/sites-enabled/
systemctl restart nginx

#Systemd Unit File setup
evalConfigTemplate < "$ODOO_SYSTEMD_TEMPLATE" > "$ODOO_SYSTEMD_PATH"
systemctl daemon-reload
systemctl enable --now "$ODOO_SERVICE_NAME"


#TODO: Add Odoo to logrotate
#TODO: Add Odoo to logwatch

#TODO: Set postgres buffer and cache https://www.soladrive.com/support/knowledgebase/4837/How-to-Optimize-an-Odoo-Server.html


#restart odoo
systemctl restart odoo
systemctl enable odoo
echo
echo "Odoo installation complete!"
echo

##TODO:##
# --no-database-list startup param for security
# auto Odoo DB Backup
# https://www.odoo.com/documentation/15.0/administration/install/deploy.html
# ^ Ssecurity section
#

##Resources##
#https://www.odoo.com/documentation/16.0/administration/install/install.html
#https://tecadmin.net/how-to-install-odoo-16-on-ubuntu-22-04/
#https://linuxize.com/post/how-to-install-odoo-15-on-ubuntu-20-04/
#https://www.soladrive.com/support/knowledgebase/4837/How-to-Optimize-an-Odoo-Server.html
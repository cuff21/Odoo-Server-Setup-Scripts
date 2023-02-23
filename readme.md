# What is this?
This repository contains helpful scripts for setting up and provisioning a Debian server for hosting the Odoo ERP system.

## Requirements
- Debian Server (or VPS) with SSH Access.
- Specs meeting the minimum hardware configuration recommendations. See the [Odoo Documentation](https://www.odoo.com/documentation/16.0/administration/install/deploy.html#builtin-server) for more information.
    
    *Warning: These specifications are very dependent on the number of users.*

- A client pc capable of running bash scripts and accessing the server via SSH

## Usage
1. Edit the `CONFIG.env` file to set the relevant details for your server. 
2. Run the `start.sh` script on the client PC. Follow on-screen prompts to begin installation.

# CONFIG.env
A configuration file must be setup in order to install correctly. Many of the parameters have good defaults, however there are some settings specific to your install that must be configured.

An [example file](SAMPLE.conf) has been provided to start building a config. Fill in the required parameters 

## Required Configuration Parameters
| Parameter | Description |
| --------- | ----------- | 
| MY_EMAIL_ADDRESS | The email address where any server generated mail will be sent |
| SERVER_HOSTNAME | Hostname of your server |
| SERVER_DOMAIN | Domain name of your server |
| SSH_PORT | *Non-Default* port to access server via SSH.<br/><br/>_**Note:** For securtiy purposes, this should not be port 22. The client will automatically connect using port 22 for initial setup, and the script will change to use this port as a part of the setup._ | 
| SMTP_RELAY_DOMAIN | The server requires an external SMTP relay server to send emails. You can use the [Gmail SMTP Server](https://support.google.com/a/answer/176600?hl=en#gmail-smpt-option) if you don't have one. |
| SMTP_RELAY_PORT | The port required by the SMTP relay server. |
| SMTP_RELAY_USERNAME | The SMTP relay login username  |
| SMTP_RELAY_PASSWORD | The SMTP relay password |
| COMPANY_NAME | The company name that will be running in Odoo.<br/> ***Important Note:*** Due to Odoo security requirements, the URL (hostname or domain) must contain this name, otherwise access will be denied.<br/><br/>Take the following example company with *Hostname* of "companyerp" and *Domain* of "example.com" (The full URL is then "companyerp.example.com")<br/><br/>**Good Company Names would be** "company", "companyerp", "example", or "ample"<br/>**Bad Company Names would be** "examples", "examplecompany", or "companyexample" |
| ODOO_ADMIN_PASSWD | The password for logging in to Odoo as the Administrator (Use a strong password to prevent being hacked) |
| ODOO_DB_PASSWORD | The Odoo database password (Make sure this is a ***very secure*** password. A long random password is best.) | 
|ODOO_WORKER_COUNT | The number of Odoo Worker Threads based on your hardware (See [Documentation](https://www.odoo.com/documentation/16.0/administration/install/deploy.html#worker-number-calculation)) | 
|ODOO_CRON_THREAD_COUNT | The number of Odoo threads for automated scheduled tasks | 
|ODOO_MAX_RAM_MB=820 | Odoo Memory allocation (See [Documentation](https://www.odoo.com/documentation/16.0/administration/install/deploy.html#memory-size-calculation)) |


## Optional advanced configuration Parameters
These parameters are preset to good default values and do not need to be modified except for advanced users.

>Note: Advanced variables have the ability to reference any of the above required variables. <br/><br/>To reference a required variable, use the format `${REQUIRED_PARAMETER_NAME}`.

| Parameter | Description | Default Value |
| --------- | ----------- | ------------- |
| ADMIN_USERNAME | The Debian username for the system admin | "companyadmin" |
| INITIAL_SSH_PORT | The starting port for SSH, This will be changed after initial configuration of the service | 22 |
| NGINX_PROXY_NAME | The reverse proxy hostname that will be used for accessing Odoo, if not the server's hostname. <br /><br />*Example:* "odoo" for odoo.mydomain.com | "${SERVER_HOSTNAME}" | 
|SERVER_EMAIL_DOMAIN| A seperate domain that may be used for automated server emails | "${SERVER_DOMAIN}" |
|SERVER_AUTOMAIL_ADDRESS| The "From:" address for any server mail | "noreply@${SERVER_EMAIL_DOMAIN}"
| NGINX_SSL_CRT_PATH | Full chain SSL certificate path | "/etc/letsencrypt/live/\${SERVER_HOSTNAME}.\${SERVER_DOMAIN}/fullchain.pem" |
| NGINX_SSL_KEY_PATH | SSL Private Key Path | "/etc/letsencrypt/live/\${SERVER_HOSTNAME}.\${SERVER_DOMAIN}/privkey.pem" |
| NGINX_SSL_TRUSTED_CERT_PATH | SSL Chain Path | "/etc/letsencrypt/live/\${SERVER_HOSTNAME}.\${SERVER_DOMAIN}/chain.pem" |
|ACME_CHALLENGE_PATH | The path which will contain the ".well-known" ACME challenge folder for SSL domain verification. This will be hosted with public viewing access, so make sure this folder contains no other files | "/var/lib/letsencrypt"
| ODOO_SYSTEM_USERNAME | the debian username for running Odoo | "odoo16" |
| ODOO_REPO | The Odoo git repo to clone for installation | 'https://github.com/odoo/odoo.git' |
| ODOO_REPO_BRANCH | The git repo branch to clone for installation | '16.0' |
| ODOO_CONF_PATH | The path for the Odoo configuration file | "/etc/odoo16.conf" |
| ODOO_SERVICE_NAME | The Systemd service name for the Odoo application service | "odoo16" |
| ODOO_INSTALL_PARENT_PATH | The parent directory of the Odoo installation | "/opt/odoo/odoo-server/" |
| ODOO_INSTALL_ROOT_PATH | The root directory of the Odoo installation | "\${ODOO_INSTALL_PARENT_PATH}/\${ODOO_REPO_BRANCH}" |
| ODOO_LOGPATH | The logfile directory of the Odoo application | "/var/log/odoo" |
| ODOO_ADDON_PATH | The Addon directory for Odoo | "${ODOO_INSTALL_ROOT_PATH}/addons" |
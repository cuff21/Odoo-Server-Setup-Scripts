#!/bin/bash -e
. CONFIG.env
. helper_functions.sh

#Tests to Run

#echo | evalConfigTemplate <<< 'The company name is ${COMPANY_NAME}'

# CONF=test.ini
# BACKUP="$CONF.bak"
# TEMPLATE=template_odoo.conf
# mv -f "$CONF" "$BACKUP"
# crudini --merge --output=- "$BACKUP" < $TEMPLATE | evalConfigTemplate > $CONF

evalConfigTemplate < template_letsencrypt.conf > test_out.conf

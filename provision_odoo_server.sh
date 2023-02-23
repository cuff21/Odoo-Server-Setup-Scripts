#!/bin/bash -e
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Imports
. "$SCRIPT_DIR/lib/config_funcs.shlib"

# Locals
CURRENT_POS="1"
RESUMEPOINT="1"
UPDATE="0"
SCRIPTS_FOLDER_TO_TRANSFER="lib"

### PARSE ARGUMENTS ###
if ! VALID_ARGS=$(getopt -o c:p:r:u --long config:,port:,resume:,update -- "$@")
then
  # getopt will output an error message, just exit
  exit 1;
fi

set -- "$VALID_ARGS"
while [ $# -gt 0 ]; do
  #consume first arg
  case "$1" in
    -c | --config) CONFIG_FILE="$2" 
        shift ;;
    -p | --port) FORCE_SSH_PORT="$2" 
        shift ;;
    -r | --resume) RESUMEPOINT="$2"
        shift ;;
    -u | --update) UPDATE="1" ;;
    --) shift
        break
        ;;
    -*) cat << EndHelp
Usage: 
  ${0##*/} [-l] [-r STEP_NUM] -c CONFIG_FILE
  ${0##*/} [-p PORT_NUM] [-u] [-r STEP_NUM] -c CONFIG_FILE

Options:
  -c CONFIG_FILE, --config CONFIG_FILE  The configuration file location
  -p PORT_NUM, --port PORT_NUM          Force SSH to always connect using the specified port PORT_NUM. 
  -u, --update                          Force the re-upload of all configuration files to the host,
                                          even if skipping to a later step using the --resume option
  -r STEP_NUM, --resume STEP_NUM        Skip to a specific step of the configuration process. This 
                                          is useful if the script previously failed and must be 
                                          restarted.

EndHelp
  esac
  #move to next arg
  shift
done

#LOAD CONFIG VARIABLES
config_load "$CONFIG_FILE"


if [[ -n "$FORCE_SSH_PORT" ]]; then
  echo "Forcing SSH port $FORCE_SSH_PORT for all connections..."
  INITIAL_SSH_PORT="$FORCE_SSH_PORT"
  SSH_PORT="$FORCE_SSH_PORT"
fi

echo
echo "This script should be run on your local pc (not on the server)."
echo "Press [CTRL]-C to quit at any time."

if (( ( RESUMEPOINT * UPDATE ) > 1 )); then
  #TODO: transfer config file with folder structure
  echo
  echo "Transferring updated setup files..."
  echo "You will be prompted for $ADMIN_USERNAME's password multiple times"
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'rm -rf ~/.server_setup'
  scp -P "$SSH_PORT" -r "$SCRIPT_DIR/$SCRIPTS_FOLDER_TO_TRANSFER/" "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN:~/.server_setup"
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'sudo rm -rf /setup && '\
    'sudo cp -r --no-preserve=mode,ownership ~/.server_setup /setup && rm -rf ~/.server_setup && sudo chmod -R u=rwx,g=rX,o-rwx /setup'

fi

###### STEP 1 ######
if (( CURRENT_POS >= RESUMEPOINT )); then

  sleep 2
  echo
  echo "Transferring setup files..."
  echo "You will be asked for the root password for your Virtual Private Server (VPS)."
  scp -p "$INITIAL_SSH_PORT" -r "$SCRIPT_DIR/$SCRIPTS_FOLDER_TO_TRANSFER" "root@$SERVER_HOSTNAME.$SERVER_DOMAIN:/setup"

  #connect SSH
  echo
  echo "Connecting to the remote system..."
  echo "You will again be asked for the VPS root password."

  ssh -p "$INITIAL_SSH_PORT" -x "root@$SERVER_HOSTNAME.$SERVER_DOMAIN" "/setup/step1.sh"

  echo
  echo "You should have seen 'Step 1 is complete.'"
  echo "If you did not see this, something went wrong. Continue only if step 2 completed successfully."
  read -r -p "Press Enter to continue... ([CTRL]-C to exit)"

  #reconnect SSH
  echo
  echo "The server is now restarting..." 
  echo "You will be reconnected to the remote system once the restart is complete."
  echo "This may take up to 60 seconds."
  echo
  echo "If you are not automatically connected, something may have gone wrong."
  echo "If necessary, try manually restarting setup with the [--resume $(( CURRENT_POS + 1 ))] option"
  echo
  echo "Waiting 10 seconds for reconnection... Press [CTRL]-C to abort installation."

  sleep 10
  echo "Attempting connection."
fi
CURRENT_POS=$(( CURRENT_POS + 1 ))


######## STEP 2 #########
if (( CURRENT_POS >= RESUMEPOINT )); then

  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'sudo /setup/step2.sh'

  echo
  echo "You should have seen 'Step 2 is complete.'"
  echo "If you did not see this, something went wrong. Continue only if step 2 completed successfully."
  read -r -p "Press Enter to continue... ([CTRL]-C to exit)"

fi
CURRENT_POS=$(( CURRENT_POS + 1 ))


######## STEP 3 #########
if (( CURRENT_POS >= RESUMEPOINT )); then
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'sudo /setup/odoo.sh'

  echo
  echo "You should have seen 'Step 3 is complete.'"
  echo "If you did not see this, something went wrong. Continue only if step 2 completed successfully."
  read -r -p "Press Enter to continue... ([CTRL]-C to exit)"
fi  
CURRENT_POS=$(( CURRENT_POS + 1 ))

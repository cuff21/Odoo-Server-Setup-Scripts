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
    -c | --config) CONFIG_FILE="$2" ; shift 2 ;;
    -p | --port) FORCE_SSH_PORT="$2" ; shift 2 ;;
    -r | --resume) RESUMEPOINT="$2" ; shift 2 ;;
    -u | --update) UPDATE="1" ; shift ;;
    --) shift ; break ;;
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
done

#LOAD CONFIG VARIABLES
: "${CONFIG_FILE:?A configuration file is required.}"
config_load "$CONFIG_FILE"

# just to ensure no full drive deletion...
: "${SERVER_SETUP_PATH:?Server setup path must be set...}"
SERVER_SETUP_PATH="$SERVER_SETUP_PATH/server_setup"

remoteConfigFile="$SERVER_SETUP_PATH/$(basename "$CONFIG_FILE")"

if [[ -n "$FORCE_SSH_PORT" ]]; then
  echo "Forcing SSH port $FORCE_SSH_PORT for all connections..."
  INITIAL_SSH_PORT="$FORCE_SSH_PORT"
  SSH_PORT="$FORCE_SSH_PORT"
fi

echo
echo "This script should be run on your local pc (not on the server)."
echo "Press [CTRL]-C to quit at any time."

if (( ( RESUMEPOINT * UPDATE ) > 1 )); then
  
  echo
  echo "Transferring updated setup files..."
  echo "You will be prompted for $ADMIN_USERNAME's password multiple times"
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'rm -rf ~/.server_setup'
  scp -P "$SSH_PORT" -r -- "$SCRIPT_DIR/$SCRIPTS_FOLDER_TO_TRANSFER/" "$remoteConfigFile" "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN:~/.server_setup"
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'sudo rm -rf "'"$SERVER_SETUP_PATH"'" && ' \
    'sudo cp -r --no-preserve=mode,ownership ~/.server_setup "'"$SERVER_SETUP_PATH"'" && ' \
    'rm -rf ~/.server_setup && sudo chmod -R u=rwx,g=rX,o-rwx "'"$SERVER_SETUP_PATH"'"'

fi

###### STEP 1 ######
if (( CURRENT_POS >= RESUMEPOINT )); then

  sleep 2
  echo
  echo "Transferring setup files..."
  echo "You will be asked for the root password for your server."
  scp -P "$INITIAL_SSH_PORT" -r -- "$SCRIPT_DIR/$SCRIPTS_FOLDER_TO_TRANSFER" "$remoteConfigFile" "root@$SERVER_HOSTNAME.$SERVER_DOMAIN:$SERVER_SETUP_PATH"

  #connect SSH
  echo
  echo "Connecting to the remote system..."
  echo "You will again be asked for the server's root password."

  ssh -p "$INITIAL_SSH_PORT" -x "root@$SERVER_HOSTNAME.$SERVER_DOMAIN" "\"$SERVER_SETUP_PATH/setup_sequence.sh\" -s 1 -c \"$remoteConfigFile\""

  echo
  echo "You should have seen 'Step 1 is complete.'"
  echo "If you did not see this, something went wrong. Continue only if step 1 completed successfully."
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

  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" "sudo \"$SERVER_SETUP_PATH/setup_sequence.sh\" -s 2 -c \"$remoteConfigFile\""

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

#!/bin/bash -e
UPDATE="0"
RESUMEPOINT="1"
CURRENT_POS="1"

if [[ $# -ne 0 ]]; then
  RESUMEPOINT="$1"
  if [[ $* == *--update* ]]; then UPDATE="1"; fi
fi

SCRIPTS_FOLDER_TO_TRANSFER="setup"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

#LOAD CONFIG VARIABLES
. "$SCRIPT_DIR/$SCRIPTS_FOLDER_TO_TRANSFER/CONFIG.env"

echo
echo "This script should be run on your local pc (not on the server)."
echo "Press [CTRL]-C to quit at any time."

if (( ( RESUMEPOINT * UPDATE ) > 1 )); then
  echo
  echo "Transferring updated setup files..."
  echo "You will be prompted for $ADMIN_USERNAME's password multiple times"
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'rm -rf ~/.server_setup'
  scp -P "$SSH_PORT" -r "$SCRIPT_DIR/$SCRIPTS_FOLDER_TO_TRANSFER/" "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN:~/.server_setup"
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'sudo rm -rf /setup && '\
    'sudo cp -r --no-preserve=mode,ownership ~/.server_setup /setup && rm -rf ~/.server_setup && sudo chmod -R u=rwx,g=rX,o-rwx /setup'

fi

if (( CURRENT_POS >= RESUMEPOINT )); then

  sleep 2
  echo
  echo "Transferring setup files..."
  echo "You will be asked for the root password for your Virtual Private Server (VPS)."


  ##CONTROL SOCKETS DO NOT WORK WITH CYGWIN WINDOWS
  ##Setup SSH Tunnel control socket
  #SOCKET_FILE="socket-$SERVER_HOSTNAME.$SERVER_DOMAIN"
  #ssh -fN -M -o ControlPath=$SOCKET_FILE root@$SERVER_HOSTNAME.$SERVER_DOMAIN
  #while [ ! -e $SOCKET_FILE ]; do sleep 0.1; done

  #Transfer Script Files
  #scp -r -o ControlPath=$SOCKET_FILE $SCRIPTS_FOLDER_TO_TRANSFER root@$SERVER_HOSTNAME.$SERVER_DOMAIN:/setup

  scp -r "$SCRIPT_DIR/$SCRIPTS_FOLDER_TO_TRANSFER" "root@$SERVER_HOSTNAME.$SERVER_DOMAIN:/setup"

  #connect SSH
  echo
  echo "Connecting to the remote system..."
  echo "You will again be asked for the VPS root password."

  #echo "After connecting, run the /setup/step1.sh script."
  #echo "If you are not automatically connected, you may run the following command:"
  #echo "ssh root@$SERVER_HOSTNAME.$SERVER_DOMAIN"
  #echo
  #read -p "Press Enter to continue... ([CTRL]-C to exit)"
  #echo "Enter the root password for your Virtual Private Server (VPS)."

  #ssh -o ControlPath=$SOCKET_FILE root@$SERVER_HOSTNAME.$SERVER_DOMAIN "/setup/step1.sh"
  ssh -x "root@$SERVER_HOSTNAME.$SERVER_DOMAIN" "/setup/step1.sh"

  ##close socket
  #ssh -S $SOCKET_FILE -O exit root@$SERVER_HOSTNAME.$SERVER_DOMAIN


  #reconnect SSH
  echo
  echo "The server is now restarting..." 
  echo "You will be reconnected to the remote system once the restart is complete."
  echo "This may take up to 60 seconds."
  echo
  echo "If you are not automatically connected, you may run the following command:"
  echo "ssh $ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN -p $SSH_PORT \"/setup/step2.sh\""
  echo
  echo "Waiting 10 seconds for reconnection... Press [CTRL]-C to abort installation."

  sleep 10
  echo "Attempting connection."
fi
CURRENT_POS=$(( CURRENT_POS + 1 ))

if (( CURRENT_POS >= RESUMEPOINT )); then

  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'sudo /setup/step2.sh'

  echo
  echo "You should have seen 'Step 2 is complete.'"
  echo "If you did not see this, something went wrong. Continue only if step 2 completed successfully."
  read -r -p "Press Enter to continue... ([CTRL]-C to exit)"

fi
CURRENT_POS=$(( CURRENT_POS + 1 ))

if (( CURRENT_POS >= RESUMEPOINT )); then
  ssh -p "$SSH_PORT" -t "$ADMIN_USERNAME@$SERVER_HOSTNAME.$SERVER_DOMAIN" 'sudo /setup/odoo.sh'


fi  
CURRENT_POS=$(( CURRENT_POS + 1 ))

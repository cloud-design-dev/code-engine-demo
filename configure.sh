#!/bin/bash 

## Setting variables
LAB="ce-lab-082521"
LAB_USER=$(echo $USER | sed 's/_/-/' | tr '[:upper:]' '[:lower:]')
PROJECT=${LAB}-${LAB_USER}
YEL='\033[1;33m'
CYN='\033[0;36m'
GRN='\033[1;32m'
RED='\033[1;31m'
NRM='\033[0m'

## Set up shell output log 
function log {
  echo -e "${CYN}[${FUNCNAME[1]}]${NRM} $*"
}

function start_session {
log "Starting session configuration for lab user ${USER}"
log "Updating IBM CLI plugins"
ibmcloud plugin update --all

log "Setting Resource group to CDE"
ibmcloud target -g CDE -q

log "Configuring COS Authentication method"
ibmcloud cos config auth --method IAM

log "Configuring COS Instance CRN"
COS_CRN=$(ibmcloud resource service-instance ${LAB}-cos-instance --output json | jq -r '.[].id')
ibmcloud cos config crn --crn ${COS_CRN} --force

log "Targeting Code Engine project ${LAB}-project"
ibmcloud ce project select --name ${LAB}-project -k
}

function gather_lab_config {
log "Gathering COS details for ${USER}"

HMAC_CREDENTIALS="${PROJECT}-hmac-keys"
ACCESS_KEY=$(ibmcloud resource service-key "${HMAC_CREDENTIALS}" --output json | jq -r '.[].credentials.cos_hmac_keys.access_key_id')
SECRET_KEY=$(ibmcloud resource service-key "${HMAC_CREDENTIALS}" --output json | jq -r '.[].credentials.cos_hmac_keys.secret_access_key')

log "Your HMAC credentials are named ${PROJECT}-hmac-keys"

log "Your source bucket is named ${PROJECT}-source-bucket"

log "Your destination bucket is named ${PROJECT}-destination-bucket"

log "Writing configuration file for ${LAB_USER} to ~/lab-config"

cat << EOF > $HOME/lab-config
SOURCE_ACCESS_KEY=${ACCESS_KEY}
SOURCE_SECRET_KEY=${SECRET_KEY}
DESTINATION_ACCESS_KEY=${ACCESS_KEY}
DESTINATION_SECRET_KEY=${SECRET_KEY}
SOURCE_BUCKET=${LAB}-${LAB_USER}-source-bucket
DESTINATION_BUCKET=${LAB}-${LAB_USER}-destination-bucket
SOURCE_REGION=us-south
DESTINATION_REGION=us-south
PROJECT=${LAB}-${LAB_USER}
LAB=${LAB}

EOF
}

function source_lab_config {
log "Attempting to source the lab configuration file ~/lab-config. Please run `source $HOME/lab-config` before continuing the project."

}

start_session
gather_lab_config
source_lab_config

if [[ -f "$HOME/lab-config" ]]; then
  . "$HOME/lab-config" 
else
  echo "Cannot locate ~/lab-config. Please run ./configure.sh to restart the session configuration tool"
fi

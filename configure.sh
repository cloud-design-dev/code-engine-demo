#!/bin/bash 

## Ask for Lab name 
## Create container registry namespace from lab name
  ## Put in check for existing lab name and append -username to namespace
  ## Set namespace as NAMESPACE
## Create Code Engine Project (with no wait so we can move on to ICOS and other stuff)
## Target shared ICOS instance 
## Create ICOS buckets from lab name and username 
  ## check if bucketname exists, create bucket with appended date stamp 
  

## Setting variables
LAB="ce-lab-082521"
LAB_USER=rtiffany
#LAB_USER=$(echo $USER | sed 's/_/-/' | tr '[:upper:]' '[:lower:]')
PROJECT=${LAB}-${LAB_USER}
YEL='\033[1;33m'
CYN='\033[0;36m'
GRN='\033[1;32m'
RED='\033[1;31m'
NRM='\033[0m'

# Set up shell output log
function func_log() {
  echo -e "[ ${CYN}>>> ${NRM} $* ${CYN}<<< ${NRM}]"
}


# ## Set up shell output log 
# function log {
#   echo -e "${CYN}[${FUNCNAME[1]}]${NRM} $*"
# }

function start_session {
func_log "Starting session configuration for lab user ${USER}"
func_log "Updating IBM CLI plugins"
ibmcloud plugin update --all

func_log "Setting Resource group to CDE"
ibmcloud target -g CDE -q

func_log "Configuring COS Authentication method"
ibmcloud cos config auth --method IAM

func_log "Configuring COS Instance CRN"
COS_CRN=$(ibmcloud resource service-instance ${LAB}-cos-instance --output json | jq -r '.[].id')
ibmcloud cos config crn --crn ${COS_CRN} --force

func_log "Targeting Code Engine project ${LAB}-project"
ibmcloud ce project select --name ${LAB}-project -k
}

function gather_lab_config {
func_log "Gathering COS details for ${USER}"

HMAC_CREDENTIALS="${PROJECT}-hmac-keys"
ACCESS_KEY=$(ibmcloud resource service-key "${HMAC_CREDENTIALS}" --output json | jq -r '.[].credentials.cos_hmac_keys.access_key_id')
SECRET_KEY=$(ibmcloud resource service-key "${HMAC_CREDENTIALS}" --output json | jq -r '.[].credentials.cos_hmac_keys.secret_access_key')

func_log "Your HMAC credentials are named ${PROJECT}-hmac-keys"

func_log "Your source bucket is named ${PROJECT}-source-bucket"

func_log "Your destination bucket is named ${PROJECT}-destination-bucket"

func_log "Writing configuration file for ${LAB_USER} to ~/lab-config"

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
func_log "Attempting to source the lab configuration file $HOME/lab-config. Please run `source $HOME/lab-config` before continuing the project just in case."

if [[ -f "$HOME/lab-config" ]]; then
  . "$HOME/lab-config" 
else
  echo "Cannot locate $HOME/lab-config. Please run ./configure.sh to restart the session configuration tool"
fi

}

start_session
gather_lab_config
source_lab_config


function create_contiainer_image {

## Create API key for Container registry
ibmcloud iam api-key-create ${PROJECT}-api-key --output json --file apiKey.json
## Export API key for container registry secret
export IBMCLOUD_API_KEY=$(jq -r .apikey < apiKey.json)

## Create Container Registry connection 
ibmcloud ce registry create --name ${PROJECT}-rg-secret --server us.icr.io --username iamapikey --password "${IBMCLOUD_API_KEY}"

ibmcloud ce build create --name ${PROJECT}-build --image us.icr.io/${LAB}-namespace/${PROJECT}-sync:1 --source https://github.com/cloud-design-dev/code-engine-minio-sync --rs ${PROJECT}-rg-secret --size small
}
#!/bin/bash 
set -x
## Ask for Lab name 
## Create container registry namespace from lab name
  ## Put in check for existing lab name and append -username to namespace
  ## Set namespace as NAMESPACE
## Create Code Engine Project (with no wait so we can move on to ICOS and other stuff)
## Target shared ICOS instance 
## Create ICOS buckets from lab name and username 
  ## check if bucketname exists, create bucket with appended date stamp 
  
 
## Setting variables
LAB="v2lab"
LAB_USER="rtiffany"
#LAB_USER=$(echo $USER | sed 's/_/-/' | tr '[:upper:]' '[:lower:]')
PROJECT=${LAB}-${LAB_USER}
YEL='\033[1;33m'
CYN='\033[0;36m'
GRN='\033[1;32m'
RED='\033[1;31m'
NRM='\033[0m'
CREATEDATE=$(date +%m%d%Y)

# Set up shell output log
function func_log() {
  echo -e "${CYN}>>> $* ${NRM}"
}

echo -n -e " ${CYN}>>> ${NRM}Name for your lab? (ignored while testing)"
#read -r LAB

function start_session {
  
  func_log "Starting session for lab: ${LAB}. Logging in to IBM Cloud and updating available plugins... "
  ibmcloud login -r us-south 
  ibmcloud target -g CDE -q
  ibmcloud plugin update --all
}

function create_assets {
  func_log "Creating a Code Project for lab: $LAB. This process can take a few minutes so we will move on to creating other assets."
  ibmcloud ce project create --name ${LAB}-project --nw --ns --quiet --tag "project:${PROJECT}" --tag "owner:${LAB_USER}"

  func_log "Creating COS instance: ${LAB}-cos"
  ibmcloud resource service-instance-create ${LAB}-cos cloud-object-storage standard global -g CDE

  ibmcloud resource tag-attach --tag-names "project:$LAB","owner:${LAB_USER}" --resource-name ${LAB}-cos
}

function configure_icr {

  func_log "Logging in to the IBM Cloud Container registry and creating $LAB namespace."
  ibmcloud cr login 
  NAMESPACE="$LAB-cr-ns"

  ## Check if namespace already exists. If it does append date
  if [[ ! -z "$(ibmcloud cr namespace-list | grep $NAMESPACE )" ]]; then
    ibmcloud cr namespace-add "$NAMESPACE"
    else
    echo "Namespace "$NAMESPACE" already exists. Creating namespace with date appended (MMDDYYYY)."
    ibmcloud cr namespace-add "$NAMESPACE-$CREATEDATE" 
  fi 

}

function configure_ce_cos {

  func_log "Configuring COS Authentication method to use IAM."
  ibmcloud cos config auth --method IAM

  func_log "Configuring COS Instance CRN"
  COS_CRN=$(ibmcloud resource service-instance ${LAB}-cos --output json | jq -r '.[].id')
  ibmcloud cos config crn --crn ${COS_CRN} --force

  func_log "Creating HMAC credentials for our Code Engine COS sync."
  ibmcloud resource service-key-create "${PROJECT}-hmac-keys" Writer --instance-name ${LAB}-cos --parameters '{"HMAC": true}' --output json > "$HOME/cos.json" 
  ACCESS_KEY=$(jq -r '.credentials.cos_hmac_keys.access_key_id' < "$HOME/cos.json")
  SECRET_KEY=$(jq -r '.credentials.cos_hmac_keys.secret_access_key' < "$HOME/cos.json")

  func_log "Your source bucket is named ${PROJECT}-source-bucket"
  func_log "Your destination bucket is named ${PROJECT}-destination-bucket"

  func_log "Checking to see if our Code Engine project is ready."

  PROJECT_STATE=$(ibmcloud code-engine project get --name ${LAB}-project --output json | jq -r '.state')

  if [ ! -z $PROJECT_STATE -eq "active" ]; then
    func_log "Project is now active, selecting it for use in $LAB"
    ibmcloud code-engine project select --name ${LAB}-project -k 
  else
    func_log "Project ${LAB}-project is not in active status, sleeping for another 2 minutes before proceeding."
    sleep 120 
  fi 

  func_log "Creating required authorization policy for Code Engine and COS."
  ibmcloud iam authorization-policy-create codeengine cloud-object-storage "Notifications Manager" --source-service-instance-name ${LAB}-project --target-service-instance-name ${LAB}-cos

  func_log "Creating API key for Code Engine and configuring conneciton to IBM Cloud Container Registry."
  ibmcloud iam api-key-create ${PROJECT}-api-key --output json --file apiKey.json
  export IBMCLOUD_API_KEY=$(jq -r .apikey < apiKey.json)

  ibmcloud ce registry create --name ${PROJECT}-rg-secret --server us.icr.io --username iamapikey --password "${IBMCLOUD_API_KEY}"

  func_log "Creating a build configuration for COS sync container"
  ibmcloud ce build create --name ${PROJECT}-build --image us.icr.io/${NAMESPACE}/${PROJECT}-sync:1 --source https://github.com/cloud-design-dev/code-engine-minio-sync --rs ${PROJECT}-rg-secret --size small

  func_log "Submitting build for COS sync container"
  ibmcloud ce buildrun submit --build ${PROJECT}-build

  
}





function create_lab_config {

func_log "Creating ${LAB} configuration file and writing to $HOME/lab-config"

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

start_session
create_assets
configure_icr
configure_ce_cos
create_lab_config
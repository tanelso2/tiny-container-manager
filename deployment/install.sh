#!/usr/bin/env bash

set -x
set -e

skipGcr=false

if [[ $1 == '--skip-gcr' ]]; then
    skipGcr=true
fi

SRC_DIR="$PWD"

TCM_DIR="/tcm"

if [[ $TCM_DIR != $SRC_DIR ]]; then
    echo "Linking $TCM_DIR to $SRC_DIR"
    ln -s $SRC_DIR $TCM_DIR
fi

echo "Creating directories for tcm"
mkdir /opt/tiny-container-manager
mkdir /opt/tiny-container-manager/containers
mkdir /opt/tiny-container-manager/keys

$TCM_DIR/deployment/install-nim.sh
. $HOME/.profile
nimble install -d

apt-get update
apt-get install -y docker.io \
                   libssl-dev

if [[ $skipGcr != "true" ]]; then
    export CLOUDSDK_CORE_DISABLE_PROMPTS=1
    curl "https://sdk.cloud.google.com" | bash > /dev/null
    echo ". $HOME/google-cloud-sdk/path.bash.inc" >> "$HOME/.profile"
    . $HOME/.profile
    
    SERVICE_ACCOUNT_FILE="/root/service-account.json"
    if [[ -z "$SERVICE_ACCOUNT_FILE" ]]; then
        echo "ERROR! Cannot find $SERVICE_ACCOUNT_FILE. Make sure it exists or run with --skip-gcr"
    else
        gcloud auth activate-service-account --key-file="${SERVICE_ACCOUNT_FILE}"
        gcloud auth configure-docker --quiet
    fi
else
    echo "Skipping installing docker-credential-gcr"
fi

cd $TCM_DIR

SERVICE=tiny-container-manager.service
SERVICE_FILE="$TCM_DIR/deployment/$SERVICE"

ln -s "$SERVICE_FILE" "/etc/systemd/system/$SERVICE"

systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl start "$SERVICE"

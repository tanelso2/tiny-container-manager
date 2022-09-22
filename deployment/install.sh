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

$TCM_DIR/deployment/install-nim.sh

apt-get update
apt-get install -y docker.io \
                   libssl-dev

if [[ $skipGcr != "true" ]]; then
    DOCKER_CREDS_GCR_RELEASE="https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.1.5/docker-credential-gcr_linux_amd64-2.1.5.tar.gz"
    T=$(mktemp -d)
    cd $T
    wget $DOCKER_CREDS_GCR_RELEASE
    tar -zxf docker-credential*.tar.gz
    cp docker-credential-gcr "/usr/local/bin"

    docker-credential-gcr configure-docker
    docker-credential-gcr gcr-login
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

#!/usr/bin/env bash

set -x

TCM_DIR="$PWD"

$TCM_DIR/deployment/install-nim.sh

apt-get update
apt-get install -y docker.io \
                   libssl-dev

DOCKER_CREDS_GCR_RELEASE="https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.1.5/docker-credential-gcr_linux_amd64-2.1.5.tar.gz"
T=$(mktemp -d)
cd $T
wget $DOCKER_CREDS_GCR_RELEASE
tar -zxf docker-credentials*.tar.gz
cp docker-credentials-gcr "/usr/local/bin"

docker-credentials-gcr configure-docker
docker-credentials-gcr gcr-login

cd $TCM_DIR

SERVICE=tiny-container-manager.service
SERVICE_FILE="$TCM_DIR/deployment/$SERVICE"

ln -s "$SERVICE_FILE" "/etc/systemd/system/$SERVICE"

systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl start "$SERVICE"

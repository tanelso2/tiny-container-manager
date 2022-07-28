#!/usr/bin/env bash

set -x

TCM_DIR="$PWD"

$TCM_DIR/deployment/install-nim.sh

apt-get update
apt-get install -y docker.io \
                   libssl-dev

SERVICE=tiny-container-manager.service
SERVICE_FILE="$TCM_DIR/deployment/$SERVICE"

ln -s "$SERVICE_FILE" "/etc/systemd/system/$SERVICE"

systemctl daemon-reload
systemctl enable "$SERVICE"
systemctl start "$SERVICE"

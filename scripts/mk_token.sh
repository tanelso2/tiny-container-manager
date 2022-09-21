#!/usr/bin/env bash

USER=${1:?"Usage: mk_token.sh <user>"}

openssl rand -hex 64 > "/opt/tiny-container-manager/keys/$USER"

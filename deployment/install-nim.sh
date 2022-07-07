#!/usr/bin/env sh

set -e

apt-get update

apt-get install -y \
    git \
    curl \
    gcc \
    xz-utils

curl https://nim-lang.org/choosenim/init.sh -sSf | sh -s -- -y

echo "export PATH=\$HOME/.nimble/bin:\$PATH" >> "$HOME/.profile"

. $HOME/.profile

nimble choosenim

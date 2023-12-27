#!/usr/bin/env bash

source "$HOME/.bashrc"
source "$HOME/.profile"

cd /tcm
nimble sync
testament p 'tests/vagrant/t*.nim'

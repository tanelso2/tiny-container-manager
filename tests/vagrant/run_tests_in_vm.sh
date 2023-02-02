#!/usr/bin/env bash

source "$HOME/.bashrc"
source "$HOME/.profile"

cd /tcm
testament p 'tests/vagrant/t*.nim'

#!/usr/bin/env bash

source "$HOME/.bashrc"

cd /tcm
testament p 'tests/vagrant/t*.nim'

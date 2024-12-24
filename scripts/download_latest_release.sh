#!/bin/bash

if [ -f tiny_container_manager ]; then
    rm -f tiny_container_manager
fi

wget https://github.com/tanelso2/tiny-container-manager/releases/latest/download/tiny_container_manager
chmod +x tiny_container_manager

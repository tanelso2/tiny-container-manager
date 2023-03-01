#!/bin/bash -x

export PATH=/root/.nimble/bin:$PATH
nimble choosenim
nimble build
## Run normally
# ./tiny_container_manager
## Memcheck
# valgrind \
#   --leak-check=full \
#   --show-leak-kinds=all \
#   --num-callers=16 \
#   ./tiny_container_manager -d \
#   >> valgrind-output 2>&1
## Massif
valgrind \
    --tool=massif \
    --stacks=yes \
    --time-unit=ms \
    ./tiny_container_manager -d \
    >> valgrind-output 2>&1
#!/bin/bash -x

export PATH=/root/.nimble/bin:$PATH
nimble choosenim
nimble build
valgrind --leak-check=full ./tiny_container_manager -d >> valgrind-output 2>&1
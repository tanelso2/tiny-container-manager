#!/bin/bash -x

export PATH=/root/.nimble/bin:$PATH
nimble choosenim
nimble run -- -d

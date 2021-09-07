#!/bin/bash -x

export PATH=/root/.nimble/bin:$PATH
nimble -d:ssl run

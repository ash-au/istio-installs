#!/bin/bash

# Set environment variables
export GLOO_VERSION="2.4"

# Set Contexts
export MGMT=cluster1
export CLUSTER1=cluster1

export CA_REGION=ap-southeast-2

export REPO=$GLOO_REPO_KEY
export ISTIO_IMAGE=1.18.2-solo
export REVISION=1-18-2

# create_ns context namespace
function create_ns () {
    if [ ! $(kubectl --context $1 get ns | grep $2) ]; then
        kubectl --context $1 create ns $2
    else
        echo "Namespace $2 already exists"
    fi
}

function display () {
    echo
    echo "###########################################################"
    echo " $@"
    echo "###########################################################"
}

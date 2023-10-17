#!/bin/bash

# Set environment variables
export GLOO_VERSION="2.3.12"

# Set Contexts
export MGMT=mgmt
export REMOTE_CONTEXT1=cluster1
export CLUSTER1=cluster1
export REMOTE_CONTEXT2=cluster2
export CLUSTER2=cluster2

#export REPO=$GLOO_REPO_KEY
#export ISTIO_IMAGE=1.18.2-solo
#export REVISION=1-18
export ISTIO_IMAGE=1.17.2-solo
export REVISION=1-17

# create_ns context namespace
function create_ns () {
    if [ ! $(kubectl --context $1 get ns | grep $2) ]; then
        kubectl --context $1 create ns $2
    else
        echo "Namespace $2 already exists"
    fi
}

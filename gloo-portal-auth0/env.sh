#!/bin/bash

# Set environment variables

# Set Contexts
export MGMT=cluster1
export CLUSTER1=cluster1

# create_ns context namespace
# create_ns <kube context> <namespace name> <security context> <routing context>
function create_ns () {
    if [ ! $(kubectl --context $1 get ns | grep $2) ]; then
        kubectl --context $1 create ns $2
    else
        echo "Namespace $2 already exists"
    fi
}

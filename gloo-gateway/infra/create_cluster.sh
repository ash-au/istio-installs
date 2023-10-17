#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

source env.sh

function install_clusters() {

    eksctl create cluster --name ${MGMT} --nodes 5 --region ${CA_REGION}

    sleep 5
    kubectl ctx mgmt=Administrator@${MGMT}.${CA_REGION}.eksctl.io

    kubectl config use-context mgmt
}

install_clusters


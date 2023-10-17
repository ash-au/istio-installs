#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

source env.sh

function delete_clusters() {
    display "Deleting Cluster ${MGMT}"
    eksctl delete cluster --name ${MGMT} --region ${CA_REGION} --wait
}

delete_clusters

#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function delete_clusters() {
    colima delete -f cluster1
    colima delete -f cluster2
    colima delete -f mgmt

    kubectl config delete-context cluster1
    kubectl config delete-context cluster2
    kubectl config delete-context mgmt
}

delete_clusters

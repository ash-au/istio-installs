#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function delete_clusters() {
    colima delete -f cluster1
    colima delete -f cluster2
    colima delete -f mgmt
}

function install_clusters() {
    colima start --cpu 4 --memory 8 --kubernetes --kubernetes-version v1.25.10+k3s1 --kubernetes-disable traefik -p mgmt --network-address
    colima start --cpu 4 --memory 8 --kubernetes --kubernetes-version v1.25.10+k3s1 --kubernetes-disable traefik -p cluster1 --network-address
    colima start --cpu 4 --memory 8 --kubernetes --kubernetes-version v1.25.10+k3s1 --kubernetes-disable traefik -p cluster2 --network-address
}

delete_clusters
sleep 10
install_clusters
sleep 10

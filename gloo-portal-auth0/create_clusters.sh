#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Function to create the cluster for gloo gateway
function install_clusters() {    
    colima start --cpu 4 --memory 8 --kubernetes --kubernetes-version v1.25.10+k3s1 --kubernetes-disable traefik -p cluster1 --network-address
    
    kubectl ctx cluster1=colima-cluster1
}

# function install_clusters() { 
# gcloud container clusters create "gloo-portal" \
#   --project "field-engineering-apac" \
#   --machine-type "e2-standard-16" --network "default" --subnetwork "default" \
#   --enable-autoscaling --min-nodes "3" --max-nodes "9" \
#   --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver \
#   --enable-autoupgrade --enable-autorepair --enable-ip-alias \
#   --max-surge-upgrade 1 --max-unavailable-upgrade 0 --enable-shielded-nodes    
    
#     kubectl ctx cluster1=gke_field-engineering-apac_australia-southeast1-b_gloo-portal
# }

install_clusters


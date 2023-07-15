#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function delete_clusters() {
    colima delete -f cluster1
}
# function delete_clusters() {
#     gcloud container clusters delete gloo-portal
#     kubectl config delete-context cluster1
# }
delete_clusters

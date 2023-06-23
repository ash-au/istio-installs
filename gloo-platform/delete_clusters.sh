#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

function delete_clusters() {
    colima delete -f cluster1
    colima delete -f cluster2
    colima delete -f mgmt
}

delete_clusters

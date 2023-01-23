#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export CTX_CLUSTER1=colima-cluster1
export CTX_CLUSTER2=colima-cluster2

function p2c() {
    set +x +e
    #read  -n 1 -p "Press to continue: " mainmenuinput
    echo " "
}

function install_sample_apps() {
    p2c
    # 1. Deploy hello world service
    kubectl create --context="${CTX_CLUSTER1}" namespace sample
    kubectl create --context="${CTX_CLUSTER2}" namespace sample

    p2c
    # 2. Enable automatic sidecar injection
    # This will need to change to discovery selectors https://istio.io/latest/blog/2021/discovery-selectors/
    kubectl label --context="${CTX_CLUSTER1}" namespace sample istio-injection=enabled
    kubectl label --context="${CTX_CLUSTER2}" namespace sample istio-injection=enabled

    p2c
    # 3. Create hello world service in both clusters
    kubectl apply --context="${CTX_CLUSTER1}" \
        -f istio/samples/helloworld/helloworld.yaml \
        -l service=helloworld -n sample
    kubectl apply --context="${CTX_CLUSTER2}" \
        -f istio/samples/helloworld/helloworld.yaml \
        -l service=helloworld -n sample

    p2c
    # Deploy v1 to cluster 1
    kubectl apply --context="${CTX_CLUSTER1}" \
        -f istio/samples/helloworld/helloworld.yaml \
        -l version=v1 -n sample
    # check pod status
    sleep 30
    kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=helloworld

    p2c
    # Deploy v2 to cluster 2
    kubectl apply --context="${CTX_CLUSTER2}" \
        -f istio/samples/helloworld/helloworld.yaml \
        -l version=v2 -n sample
    # check pod status
    sleep 30
    kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=helloworld

    p2c
    # Deploy sleep app
    kubectl apply --context="${CTX_CLUSTER1}" \
        -f istio/samples/sleep/sleep.yaml -n sample
    kubectl apply --context="${CTX_CLUSTER2}" \
        -f istio/samples/sleep/sleep.yaml -n sample
    sleep 30
    kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l app=sleep
    kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l app=sleep
}

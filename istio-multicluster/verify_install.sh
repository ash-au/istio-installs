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

function enable_proxy_logs_app1() {
    hwpodname=$(kubectl --context="${CTX_CLUSTER1}" -n sample get pods -l app=helloworld -o jsonpath='{.items[0].metadata.name}')
    echo $hwpodname
    istioctl proxy-config log ${hwpodname}.sample --level router:debug --context ${CTX_CLUSTER1}
    echo "kubectl --context="${CTX_CLUSTER1}" -n sample logs ${hwpodname} -f"
}

function enable_proxy_logs_gw1() {
    hwpodname=$(kubectl --context="${CTX_CLUSTER1}" -n istio-system get pods -l app=istio-eastwestgateway -o jsonpath='{.items[0].metadata.name}')
    echo $hwpodname
    istioctl proxy-config log ${hwpodname}.istio-system --level router:debug --context ${CTX_CLUSTER1}
    echo "kubectl --context="${CTX_CLUSTER1}" -n istio-system logs ${hwpodname} -f"
}

function enable_proxy_logs_app2() {
    hwpodname=$(kubectl --context="${CTX_CLUSTER2}" -n sample get pods -l app=helloworld -o jsonpath='{.items[0].metadata.name}')
    echo $hwpodname
    istioctl proxy-config log ${hwpodname}.sample --level router:debug --context ${CTX_CLUSTER2}
    echo "kubectl --context="${CTX_CLUSTER2}" -n sample logs ${hwpodname} -f"
}

function enable_proxy_logs_gw2() {
    hwpodname=$(kubectl --context="${CTX_CLUSTER2}" -n istio-system get pods -l app=istio-eastwestgateway -o jsonpath='{.items[0].metadata.name}')
    echo $hwpodname
    istioctl proxy-config log ${hwpodname}.istio-system --level router:debug --context ${CTX_CLUSTER2}
    echo "kubectl --context="${CTX_CLUSTER2}" -n istio-system logs ${hwpodname} -f"
}

function enable_proxy_logs() {
    enable_proxy_logs_app1
    enable_proxy_logs_app2
    enable_proxy_logs_gw1
    enable_proxy_logs_gw2
}

#enable_proxy_logs

function check_lb () {
    hwpodname=$(kubectl --context="${CTX_CLUSTER1}" -n sample get pods -l app=sleep -o jsonpath='{.items[0].metadata.name}')
    echo $hwpodname
    # Basically this should be load balancing between local service (cluster) ip
    istioctl --context ${CTX_CLUSTER1} proxy-config endpoints -n sample $hwpodname --cluster "outbound|5000||helloworld.sample.svc.cluster.local"

    hwpodname=$(kubectl --context="${CTX_CLUSTER2}" -n sample get pods -l app=sleep -o jsonpath='{.items[0].metadata.name}')
    echo $hwpodname
    # Basically this should be load balancing between local service (cluster) ip
    istioctl --context ${CTX_CLUSTER2}  proxy-config endpoints -n sample $hwpodname --cluster "outbound|5000||helloworld.sample.svc.cluster.local"
}

#install_sample_apps

check_lb

for i in {1..6}; do
    kubectl exec --context="${CTX_CLUSTER1}" -n sample -c sleep \
        "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
        app=sleep -o jsonpath='{.items[0].metadata.name}')" \
        -- curl -sS helloworld.sample:5000/hello
done

for i in {1..6}; do
    kubectl exec --context="${CTX_CLUSTER2}" -n sample -c sleep \
        "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l \
        app=sleep -o jsonpath='{.items[0].metadata.name}')" \
        -- curl -sS helloworld.sample:5000/hello
done

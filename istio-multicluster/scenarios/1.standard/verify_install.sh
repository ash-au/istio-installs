#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export CTX_CLUSTER1=colima-cluster1
export CTX_CLUSTER2=colima-cluster2

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

echo "invoking from cluster1"
for i in {1..6}; do
    kubectl exec --context="${CTX_CLUSTER1}" -n sample -c sleep \
        "$(kubectl get pod --context="${CTX_CLUSTER1}" -n sample -l \
        app=sleep -o jsonpath='{.items[0].metadata.name}')" \
        -- curl -sS helloworld.sample:5000/hello
done

echo "invoking from cluster2"
for i in {1..6}; do
    kubectl exec --context="${CTX_CLUSTER2}" -n sample -c sleep \
        "$(kubectl get pod --context="${CTX_CLUSTER2}" -n sample -l \
        app=sleep -o jsonpath='{.items[0].metadata.name}')" \
        -- curl -sS helloworld.sample:5000/hello
done

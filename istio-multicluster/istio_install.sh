#!/bin/bash
set -euxo pipefail
IFS=$'\n\t'

# Set environment variables
export CTX_CLUSTER1=colima-cluster1
export CTX_CLUSTER2=colima-cluster2

function install_istio_on_cluster () {

    # Based on https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/
    kctx="colima-cluster$1"
    echo $kctx
    kubectl --context="${kctx}" get namespace istio-system && \
    kubectl --context="${kctx}" label namespace istio-system topology.istio.io/network=network$1 --overwrite

    cat <<EOF > cluster$1.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
    values:
        global:
            meshID: mesh$1
            multiCluster:
                clusterName: cluster$1
            network: network$1
EOF
    # Install Istio
    istioctl install --context="${kctx}" -f cluster$1.yaml -y

    # Install east-west gateway
    # East West gateway may not work with standard config as it uses the same healthcheck port as ingress gateway 
    # We'll have to modify east-west gateway configuration
    # This may be a colima limitation onl
    #./istio/samples/multicluster/gen-eastwest-gateway.sh --network network1 | istioctl --context="${kctx}" install -y -f -
    ./istio/samples/multicluster/gen-eastwest-gateway.sh --network network$1 > ew-gw.yaml
    
    gsed -i "s/15021/15022/g" ew-gw.yaml

    istioctl install --context "${kctx}" -f ew-gw.yaml -y
    # Check status of east-west gateway
    sleep 20
    kubectl --context="${kctx}" get svc istio-eastwestgateway -n istio-system
    # Expose services to east-west gateway
    kubectl --context="${kctx}" apply -n istio-system -f ./istio/samples/multicluster/expose-services.yaml
}

function enable_endpoint_discovery () {
    istioctl x create-remote-secret --context="${CTX_CLUSTER1}" --name=cluster1 | kubectl apply -f - --context="${CTX_CLUSTER2}"

    istioctl x create-remote-secret --context="${CTX_CLUSTER2}" --name=cluster2 | kubectl apply -f - --context="${CTX_CLUSTER1}"
}

install_istio_on_cluster 1
install_istio_on_cluster 2
enable_endpoint_discovery
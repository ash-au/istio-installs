#!/bin/bash
#set -euxo pipefail
IFS=$'\n\t'

# Set environment variables
export CTX_CLUSTER1=colima-cluster1
export CTX_CLUSTER2=colima-cluster2

function install_istio_on_cluster () {

    # Based on https://istio.io/latest/docs/setup/install/multicluster/multi-primary_multi-network/
    kctx=$CTX_CLUSTER1
    [ $1 -eq 2 ] && kctx=$CTX_CLUSTER2
    echo $kctx
    kubectl --context="${kctx}" get namespace istio-system && \
    kubectl --context="${kctx}" label namespace istio-system topology.istio.io/network=network$1 --overwrite

    cat <<EOF > tmp/cluster$1.yaml
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
    values:
        global:
            meshID: mesh1
            multiCluster:
                clusterName: cluster$1
            network: network$1
    meshConfig:
        accessLogFile: /dev/stdout
        defaultConfig:
            proxyMetadata:
                # Enable basic DNS proxying
                ISTIO_META_DNS_CAPTURE: "true"
                # Enable automatic address allocation, optional
                ISTIO_META_DNS_AUTO_ALLOCATE: "true"
EOF
    # Install Istio
    istioctl install --context="${kctx}" -f tmp/cluster$1.yaml -y

    # Install east-west gateway
    # East West gateway may not work with standard config as it uses the same healthcheck port as ingress gateway 
    # We'll have to modify east-west gateway configuration
    # This may be a colima limitation only
    #./istio/samples/multicluster/gen-eastwest-gateway.sh --network network1 | istioctl --context="${kctx}" install -y -f -
    #./istio/samples/multicluster/gen-eastwest-gateway.sh --network network$1 > ew-gw.yaml
    ./istio/samples/multicluster/gen-eastwest-gateway.sh \
    --mesh mesh1 --cluster cluster$1 --network network$1 > tmp/ew-gw$1.yaml
    
    gsed -i "s/15021/15022/g" tmp/ew-gw$1.yaml

    istioctl install --context "${kctx}" -f tmp/ew-gw$1.yaml -y
    # Check status of east-west gateway
    sleep 20
    kubectl --context="${kctx}" get svc istio-eastwestgateway -n istio-system
    # Expose services to east-west gateway
    kubectl --context="${kctx}" apply -n istio-system -f ./istio/samples/multicluster/expose-services.yaml
}

function enable_endpoint_discovery () {
    istioctl create-remote-secret --context="${CTX_CLUSTER1}" --name=cluster1 | kubectl apply -f - --context="${CTX_CLUSTER2}"

    istioctl create-remote-secret --context="${CTX_CLUSTER2}" --name=cluster2 | kubectl apply -f - --context="${CTX_CLUSTER1}"
}

install_istio_on_cluster 1
install_istio_on_cluster 2
enable_endpoint_discovery
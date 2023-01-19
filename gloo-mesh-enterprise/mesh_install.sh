#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export GLOO_VERSION=2.1.4
export MGMT_CLUSTER=colima-mgmt
export REMOTE_CLUSTER1=colima-cluster1
export REMOTE_CLUSTER2=colima-cluster2
export MGMT_CONTEXT=colima-mgmt
export REMOTE_CONTEXT1=colima-cluster1
export REMOTE_CONTEXT2=colima-cluster2

function delete_clusters() {
    colima delete -f cluster1
    colima delete -f cluster2
    colima delete -f mgmt
}

function install_clusters() {
    colima start --cpu 4 --memory 8 --kubernetes --kubernetes-version v1.23.15-rc3+k3s1 --kubernetes-disable traefik -p mgmt --network-address
    colima start --cpu 4 --memory 8 --kubernetes --kubernetes-version v1.23.15-rc3+k3s1 --kubernetes-disable traefik -p cluster1 --network-address
    colima start --cpu 4 --memory 8 --kubernetes --kubernetes-version v1.23.15-rc3+k3s1 --kubernetes-disable traefik -p cluster2 --network-address
}

function install_gloo_mgmt() {
    # First update helm
    helm repo add gloo-mesh-enterprise https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-enterprise
    helm repo add gloo-mesh-agent https://storage.googleapis.com/gloo-mesh-enterprise/gloo-mesh-agent
    helm repo update

    # Create namespace for installation
    kubectl create ns gloo-mesh --context $MGMT_CONTEXT

    # Create values file
    helm show values gloo-mesh-enterprise/gloo-mesh-enterprise --version $GLOO_VERSION > values-mgmt-plane-env.yaml
    #open values-mgmt-plane-env.yaml
    gsed -i "s/mgmt-cluster/$MGMT_CLUSTER/g" values-mgmt-plane-env.yaml
    gsed -i "s/licenseKey: \"\"/licenseKey: $GLOO_MESH_LICENSE_KEY/" values-mgmt-plane-env.yaml

    # Install Gloo Mesh
    helm install gloo-mgmt gloo-mesh-enterprise/gloo-mesh-enterprise \
    --namespace gloo-mesh \
    --kube-context $MGMT_CONTEXT \
    --set licenseKey=$GLOO_MESH_LICENSE_KEY \
    --values values-mgmt-plane-env.yaml

    mv values* ./tmp

}

#function install_gloo_agent (remote_cluster, remote_context) {
function install_gloo_agent () {
  remote_cluster=$1
  remote_context=$2
  mgmt_server=$3

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
    name: ${remote_cluster}
    namespace: gloo-mesh
    labels:
        env: prod
spec:
    clusterDomain: cluster.local
EOF

    kubectl create ns gloo-mesh --context $remote_context

    kubectl get secret relay-root-tls-secret -n gloo-mesh --context $MGMT_CONTEXT -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
    kubectl create secret generic relay-root-tls-secret -n gloo-mesh --context $remote_context --from-file ca.crt=ca.crt
    rm ca.crt

    kubectl get secret relay-identity-token-secret -n gloo-mesh --context $MGMT_CONTEXT -o jsonpath='{.data.token}' | base64 -d > token
    kubectl create secret generic relay-identity-token-secret -n gloo-mesh --context $remote_context --from-file token=token
    rm token

    helm show values gloo-mesh-agent/gloo-mesh-agent --version $GLOO_VERSION > values-data-plane-env.yaml
    gsed -i "s/cluster: \"\"/cluster: $remote_cluster/" ./values-data-plane-env.yaml
    gsed -i "s/serverAddress: \"\"/serverAddress: $mgmt_server/" ./values-data-plane-env.yaml

    helm install gloo-agent gloo-mesh-agent/gloo-mesh-agent \
    --namespace gloo-mesh \
    --kube-context $remote_context \
    --values values-data-plane-env.yaml

    mv values* ./tmp
}

delete_clusters
sleep 10
install_clusters
sleep 10
install_gloo_mgmt 
#It takes about a minute for server to come up
sleep 60

MGMT_SERVER_NETWORKING_DOMAIN=$(kubectl get svc -n gloo-mesh gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
MGMT_SERVER_NETWORKING_PORT=$(kubectl -n gloo-mesh get service gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
MGMT_SERVER_NETWORKING_ADDRESS=${MGMT_SERVER_NETWORKING_DOMAIN}:${MGMT_SERVER_NETWORKING_PORT}
echo $MGMT_SERVER_NETWORKING_ADDRESS

#export REMOTE_CLUSTER=$REMOTE_CLUSTER1
#export REMOTE_CONTEXT=$REMOTE_CONTEXT1
install_gloo_agent $REMOTE_CLUSTER1 $REMOTE_CONTEXT1 $MGMT_SERVER_NETWORKING_ADDRESS

#export REMOTE_CLUSTER=$REMOTE_CLUSTER2
#export REMOTE_CONTEXT=$REMOTE_CONTEXT2
install_gloo_agent $REMOTE_CLUSTER2 $REMOTE_CONTEXT2 $MGMT_SERVER_NETWORKING_ADDRESS

sleep 60
meshctl check --kubecontext $MGMT_CONTEXT
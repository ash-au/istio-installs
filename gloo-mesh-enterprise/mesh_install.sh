#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export GLOO_VERSION="2.3.5"
export MGMT_CLUSTER=colima-mgmt
export REMOTE_CLUSTER1=colima-cluster1
export REMOTE_CLUSTER2=colima-cluster2
export MGMT_CONTEXT=colima-mgmt
export REMOTE_CONTEXT1=colima-cluster1
export REMOTE_CONTEXT2=colima-cluster2

function install_gloo_mgmt() {
    # First update helm
    set +x +e
    helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
    helm repo update

    # Create namespace for installation
    if [ `kubectl get ns | grep gloo-mesh` ]
    then
        echo "Namespace exists"
    else
        kubectl create ns gloo-mesh --context $MGMT_CONTEXT
    fi

    # Add Gloo Platform CRDS
    helm upgrade -i gloo-platform-crds gloo-platform/gloo-platform-crds \
    --kube-context $MGMT_CONTEXT \
    --namespace=gloo-mesh \
    --create-namespace \
    --version $GLOO_VERSION
    
    # Install Gloo Mesh
    helm upgrade -i gloo-platform gloo-platform/gloo-platform \
    --kube-context $MGMT_CONTEXT \
    --namespace gloo-mesh \
    --version $GLOO_VERSION \
    --values mgmt-server.yaml \
    --set common.cluster=$MGMT_CLUSTER \
    --set licensing.glooMeshLicenseKey=$GLOO_MESH_LICENSE_KEY

    kubectl --context ${MGMT_CONTEXT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
}

#function install_gloo_agent (remote_cluster, remote_context) {
function install_gloo_agent () {
    remote_cluster=$1
    remote_context=$2
    mgmt_server=$3
    tel_server=$4

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
    name: ${REMOTE_CLUSTER}
    namespace: gloo-mesh
    labels:
        env: prod
spec:
    clusterDomain: cluster.local
EOF

    if [ `kubectl get ns | grep gloo-mesh` ]
    then
        echo "Namespace exists"
    else
        kubectl create ns gloo-mesh --context $REMOTE_CONTEXT
    fi

    # Install Gloo Platform CRDs on this cluster
    helm upgrade -i gloo-platform-crds gloo-platform/gloo-platform-crds \
    --kube-context $REMOTE_CONTEXT \
    --namespace=gloo-mesh \
    --create-namespace \
    --version $GLOO_VERSION

    kubectl get secret relay-root-tls-secret -n gloo-mesh --context $MGMT_CONTEXT -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt
    kubectl create secret generic relay-root-tls-secret -n gloo-mesh --context $REMOTE_CONTEXT --from-file ca.crt=ca.crt
    rm ca.crt

    kubectl get secret relay-identity-token-secret -n gloo-mesh --context $MGMT_CONTEXT -o jsonpath='{.data.token}' | base64 -d > token
    kubectl create secret generic relay-identity-token-secret -n gloo-mesh --context $REMOTE_CONTEXT --from-file token=token
    rm token

    helm upgrade -i gloo-platform gloo-platform/gloo-platform \
    --namespace gloo-mesh \
    --kube-context $REMOTE_CONTEXT \
    --version $GLOO_VERSION \
    --values agent.yaml \
    --set common.cluster=$REMOTE_CLUSTER \
    --set glooAgent.relay.serverAddress=$mgmt_server \
    --set telemetryCollector.config.exporters.otlp.endpoint=$tel_server
}

function setup_workspaces () {

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: $MGMT_CLUSTER
  namespace: gloo-mesh
spec:
  workloadClusters:
    - name: '*'
      namespaces:
        - name: '*'
EOF


kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: $MGMT_CLUSTER
  namespace: gloo-mesh
spec:
  options:
    serviceIsolation:
      enabled: false
    federation:
      enabled: false
      serviceSelector:
      - {}
    eastWestGateways:
    - selector:
        labels:
          istio: eastwestgateway
EOF


}

function label_nodes () {
    kubectl label nodes --all --context $REMOTE_CONTEXT topology.kubernetes.io/region=${REMOTE_CLUSTER}
    #kubectl label node ${REMOTE_CLUSTER} --context $REMOTE_CONTEXT1 topology.kubernetes.io/zone="${REMOTE_CLUSTER}-1"
}

install_gloo_mgmt 
#It takes about a minute for server to come up
sleep 60
#setup_workspaces

# Get management server address
MGMT_SERVER_NETWORKING_DOMAIN=$(kubectl get svc -n gloo-mesh gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
MGMT_SERVER_NETWORKING_PORT=$(kubectl -n gloo-mesh get service gloo-mesh-mgmt-server --context $MGMT_CONTEXT -o jsonpath='{.spec.ports[?(@.name=="grpc")].port}')
MGMT_SERVER_NETWORKING_ADDRESS=${MGMT_SERVER_NETWORKING_DOMAIN}:${MGMT_SERVER_NETWORKING_PORT}
echo $MGMT_SERVER_NETWORKING_ADDRESS

# Get OTel Gateway address
export TELEMETRY_GATEWAY_IP=$(kubectl get svc -n gloo-mesh gloo-telemetry-gateway --context $MGMT_CONTEXT -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
export TELEMETRY_GATEWAY_PORT=$(kubectl -n gloo-mesh get service gloo-telemetry-gateway --context $MGMT_CONTEXT -o jsonpath='{.spec.ports[?(@.name=="otlp")].port}')
export TELEMETRY_GATEWAY_ADDRESS=${TELEMETRY_GATEWAY_IP}:${TELEMETRY_GATEWAY_PORT}
echo $TELEMETRY_GATEWAY_ADDRESS

export REMOTE_CLUSTER=$REMOTE_CLUSTER1
export REMOTE_CONTEXT=$REMOTE_CONTEXT1
install_gloo_agent $REMOTE_CLUSTER1 $REMOTE_CONTEXT1 $MGMT_SERVER_NETWORKING_ADDRESS $TELEMETRY_GATEWAY_ADDRESS
label_nodes

export REMOTE_CLUSTER=$REMOTE_CLUSTER2
export REMOTE_CONTEXT=$REMOTE_CONTEXT2
install_gloo_agent $REMOTE_CLUSTER2 $REMOTE_CONTEXT2 $MGMT_SERVER_NETWORKING_ADDRESS $TELEMETRY_GATEWAY_ADDRESS
label_nodes

sleep 10
meshctl check --kubecontext $MGMT_CONTEXT
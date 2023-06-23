#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh

# Get environment variables
export ENDPOINT_GLOO_MESH=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-mesh-mgmt-server -o jsonpath='{.status.loadBalancer.ingress[0].*}'):9900
export HOST_GLOO_MESH=$(echo ${ENDPOINT_GLOO_MESH} | cut -d: -f1)
export ENDPOINT_TELEMETRY_GATEWAY=$(kubectl --context ${MGMT} -n gloo-mesh get svc gloo-telemetry-gateway -o jsonpath='{.status.loadBalancer.ingress[0].*}'):4317
echo $HOST_GLOO_MESH
echo "Gloo Mesh Endpoint: $ENDPOINT_GLOO_MESH"
echo "Telemetry Endpoing: $ENDPOINT_TELEMETRY_GATEWAY"

function register_cluster() {
  # Register Cluster
  kubectl apply --context ${MGMT} -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: KubernetesCluster
metadata:
  name: ${CLUSTER}
  namespace: gloo-mesh
spec:
  clusterDomain: cluster.local
EOF

  # Check and Create namespace
  if [ ! $(kubectl --context ${CLUSTER} get ns | grep gloo-mesh) ]; then
    kubectl --context ${CLUSTER} create ns gloo-mesh
  fi

  if [ ! $(kubectl get secret -n gloo-mesh --context ${CLUSTER} | grep relay-root-tls-secret) ]; then
    kubectl get secret relay-root-tls-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.ca\.crt}' | base64 -d >ca.crt
    kubectl create secret generic relay-root-tls-secret -n gloo-mesh --context ${CLUSTER} --from-file ca.crt=ca.crt
    rm ca.crt
  fi

  if [ ! $(kubectl get secret -n gloo-mesh --context ${CLUSTER} | grep relay-identity-token-secret) ]; then
    kubectl get secret relay-identity-token-secret -n gloo-mesh --context ${MGMT} -o jsonpath='{.data.token}' | base64 -d >token
    kubectl create secret generic relay-identity-token-secret -n gloo-mesh --context ${CLUSTER} --from-file token=token
    rm token
  fi
  helm upgrade --install gloo-platform-crds gloo-platform/gloo-platform-crds \
    --namespace=gloo-mesh \
    --kube-context=${CLUSTER} \
    --version=${GLOO_VERSION}
  helm upgrade --install gloo-platform gloo-platform/gloo-platform \
    --namespace=gloo-mesh \
    --kube-context=${CLUSTER} \
    --version=${GLOO_VERSION} \
    -f - <<EOF
common:
  cluster: ${CLUSTER}
glooAgent:
  enabled: true
  relay:
    serverAddress: ${ENDPOINT_GLOO_MESH}
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: ${ENDPOINT_TELEMETRY_GATEWAY}
EOF
}

export CLUSTER=$CLUSTER1
register_cluster
export CLUSTER=$CLUSTER2
register_cluster

# Check if clusters have been registered
meshctl --kubecontext ${MGMT} check

# Specify which gateways to use for cross-cluster traffic
kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: global
  namespace: gloo-mesh
spec:
  options:
    eastWestGateways:
      - selector:
          labels:
            istio: eastwestgateway
EOF
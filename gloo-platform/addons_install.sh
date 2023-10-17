#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh

# Get deployed istio revision
export REVISION=$(kubectl get pod -L app=istiod -n istio-system --context $REMOTE_CONTEXT1 -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
echo $REVISION

function install_addons() {

  # if [ ! $(kubectl --context ${CLUSTER} get ns | grep gloo-mesh-addons) ]; then
  #   kubectl --context ${CLUSTER} create namespace gloo-mesh-addons
  # fi
  create_ns ${CLUSTER} gloo-mesh-addons
  kubectl --context ${CLUSTER} label namespace gloo-mesh-addons istio.io/rev=${REVISION} --overwrite

  helm upgrade --install gloo-platform gloo-platform/gloo-platform \
    --namespace gloo-mesh-addons \
    --kube-context=${CLUSTER} \
    --version ${GLOO_VERSION} \
    -f - <<EOF
common:
  cluster: ${CLUSTER}
glooAgent:
  enabled: false
extAuthService:
  enabled: true
  extAuth: 
    apiKeyStorage: 
      name: redis
      enabled: true
      config: 
        connection: 
          host: redis.gloo-mesh-addons:6379
      secretKey: ThisIsSecret
rateLimiter:
  enabled: true
EOF

# Create ExtAuth Server
kubectl apply --context ${CLUSTER} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: ExtAuthServer
metadata:
  name: ext-auth-server
  namespace: gloo-mesh-addons
spec:
  destinationServer:
    ref:
      cluster: ${CLUSTER}
      name: ext-auth-service
      namespace: gloo-mesh-addons
    port:
      name: grpc
EOF

# Create RateLimit Server
kubectl apply --context ${CLUSTER} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerSettings
metadata:
  name: rate-limit-server
  namespace: gloo-mesh-addons
spec:
  destinationServer:
    ref:
      cluster: ${CLUSTER}
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
EOF
}

export CLUSTER=$CLUSTER1
install_addons
export CLUSTER=$CLUSTER2
install_addons
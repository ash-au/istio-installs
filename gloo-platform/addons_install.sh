#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh

export ISTIO_VERSION=1.17.2
export REPO=$GLOO_REPO_KEY
export ISTIO_IMAGE=1.17.2-solo
# Get deployed istio revision
export REVISION=$(kubectl get pod -L app=istiod -n istio-system --context $REMOTE_CONTEXT1 -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
echo $REVISION

function install_addons() {

  if [ ! $(kubectl --context ${CLUSTER} get ns | grep gloo-mesh-addons) ]; then
    kubectl --context ${CLUSTER} create namespace gloo-mesh-addons
  fi
  kubectl --context ${CLUSTER} label namespace gloo-mesh-addons istio.io/rev=${REVISION} --overwrite

  helm upgrade --install gloo-platform gloo-platform/gloo-platform \
    --namespace gloo-mesh-addons \
    --kube-context=${CLUSTER} \
    --version ${GLOO_VERSION} \
    -f - <<EOF
common:
  cluster: ${CLUSTER}
glooPortalServer:
  enabled: true
  apiKeyStorage:
    config:
      host: redis.gloo-mesh-addons:6379
    configPath: /etc/redis/config.yaml
    secretKey: ThisIsSecret
glooAgent:
  enabled: false
extAuthService:
  enabled: true
  extAuth: 
    apiKeyStorage: 
      name: redis
      config: 
        connection: 
          host: redis.gloo-mesh-addons:6379
      secretKey: ThisIsSecret
rateLimiter:
  enabled: true
EOF
}

export CLUSTER=$CLUSTER1
install_addons
export CLUSTER=$CLUSTER2
install_addons
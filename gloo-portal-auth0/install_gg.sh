#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh

helm repo add gloo-platform https://storage.googleapis.com/gloo-platform/helm-charts
helm repo update
create_ns ${MGMT} gloo-mesh
create_ns ${MGMT} gloo-mesh-addons

helm upgrade --install gloo-platform-crds https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts/gloo-platform-crds-2.4.0-beta2-2023-06-28-main-ddf3e1ba7.tgz \
--namespace gloo-mesh \
--kube-context ${MGMT} \
--version=2.4.0-beta2-2023-06-28-main-ddf3e1ba7

helm upgrade --install gloo-platform https://storage.googleapis.com/gloo-platform-dev/platform-charts/helm-charts/gloo-platform-2.4.0-beta2-2023-06-28-main-ddf3e1ba7.tgz \
--namespace gloo-mesh \
--kube-context ${MGMT} \
--version=2.4.0-beta2-2023-06-28-main-ddf3e1ba7 \
 -f -<<EOF
licensing:
  licenseKey: ${GLOO_MESH_LICENSE_KEY}
common:
  cluster: ${MGMT}
glooMgmtServer:
  enabled: true
  ports:
    healthcheck: 8091
  registerCluster: true
prometheus:
  enabled: true
redis:
  deployment:
    enabled: true
telemetryGateway:
  enabled: true
  service:
    type: LoadBalancer
glooUi:
  enabled: true
  serviceType: LoadBalancer
glooPortalServer:
  enabled: true
  apiKeyStorage:
    redis:
      enabled: true
      address: redis.gloo-mesh-addons:6379
    secretKey: ThisIsSecret
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
    image:
      registry: gcr.io/gloo-mesh
rateLimiter:
  enabled: true
  rateLimiter:
    image:
      registry: gcr.io/gloo-mesh
istioInstallations:
  enabled: true
  northSouthGateways:
    - enabled: true
      name: istio-ingressgateway
      installations:
        - clusters:
          - name: ${MGMT}
            activeGateway: false
          gatewayRevision: auto
          istioOperatorSpec:
            hub: us-docker.pkg.dev/gloo-mesh/istio-workshops
            tag: 1.17.2-solo
            profile: empty
            values:
              global:
                proxy:
                  privileged: true
            components:
              ingressGateways:
                - name: istio-ingressgateway
                  namespace: istio-gateways
                  enabled: true
                  label:
                    istio: ingressgateway
glooAgent:
  enabled: true
  relay:
    serverAddress: gloo-mesh-mgmt-server:9900
    authority: gloo-mesh-mgmt-server.gloo-mesh
telemetryCollector:
  enabled: true
  config:
    exporters:
      otlp:
        endpoint: gloo-telemetry-gateway:4317
EOF
kubectl --context ${MGMT} -n gloo-mesh rollout status deploy/gloo-mesh-mgmt-server
kubectl --context ${MGMT} delete workspaces -A --all
sleep 10
until [[ $(kubectl --context ${MGMT} -n istio-gateways get deploy -o json | jq '[.items[].status.readyReplicas] | add') -ge 1 ]]; do
  sleep 1
done
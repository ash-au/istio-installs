#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh
export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)

# First create RateLimitClient Config
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: RateLimitClientConfig
metadata:
  name: productpage
  namespace: bookinfo-frontends
spec:
  raw:
    rateLimits:
    - setActions:
      - requestHeaders:
          descriptorKey: usagePlan
          headerName: X-Solo-Plan
      - metadata:
          descriptorKey: userId
          metadataKey:
            key: envoy.filters.http.ext_authz
            path:
              - key: userId
EOF

# First create RateLimitServer Config
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RateLimitServerConfig
metadata:
  name: productpage
  namespace: bookinfo-frontends
spec:
  destinationServers:
  - ref:
      cluster: ${CLUSTER1}
      name: rate-limiter
      namespace: gloo-mesh-addons
    port:
      name: grpc
  raw:
    setDescriptors:
      - simpleDescriptors:
          - key: userId
          - key: usagePlan
            value: bronze
        rateLimit:
          requestsPerUnit: 1
          unit: MINUTE
      - simpleDescriptors:
          - key: userId
          - key: usagePlan
            value: silver
        rateLimit:
          requestsPerUnit: 3
          unit: MINUTE
      - simpleDescriptors:
          - key: userId
          - key: usagePlan
            value: gold
        rateLimit:
          requestsPerUnit: 5
          unit: MINUTE
EOF

# Attach Policy
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: trafficcontrol.policy.gloo.solo.io/v2
kind: RateLimitPolicy
metadata:
  name: productpage
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        ratelimited: "true"
  config:
    serverSettings:
      name: rate-limit-server
      namespace: gloo-mesh-addons
      cluster: ${CLUSTER1}
    ratelimitClientConfig:
      name: productpage
      namespace: bookinfo-frontends
      cluster: ${CLUSTER1}
    ratelimitServerConfig:
      name: productpage
      namespace: bookinfo-frontends
      cluster: ${CLUSTER1}
    phase:
      postAuthz:
        priority: 1
EOF
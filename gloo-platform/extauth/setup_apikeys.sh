#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh

# 1. Lets create a secret to store api key and metadata
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: user-id-12345
  namespace: httpbin
  labels:
    extauth: apikey
type: extauth.solo.io/apikey
data:
  api-key: TjJZd01ESXhaVEV0TkdVek5TMWpOemd6TFRSa1lqQXRZakUyWXpSa1pHVm1OamN5
  user-id: dXNlci1pZC0xMjM0NQ==
  user-email: dXNlcjEyMzQ1QGVtYWlsLmNvbQ==
EOF

# 2. Create ExtAuthServer. Apparently there needs to be an ExtAuthServer per workspace
# kubectl apply -f - <<EOF
# apiVersion: admin.gloo.solo.io/v2
# kind: ExtAuthServer
# metadata:
#   name: ext-auth-server
#   namespace: httpbin
# spec:
#   destinationServer:
#     port:
#       number: 8083
#     ref:
#       cluster: cluster1
#       name: ext-auth-service
#       namespace: gloo-mesh-addons
# EOF


# 3. Create ExtAuthPolicy
kubectl apply -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: httpbin-apikey
  namespace: httpbin
  labels:
    route: httpbin
spec:
  applyToRoutes:
  - route:
      # labels:
      #   expose: "true"
      workspace: httpbin
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: cluster1
    glooAuth:
      configs:
      - apiKeyAuth:
          headerName: api-key
          headersFromMetadataEntry:
            x-user-email: 
              name: user-email
          k8sSecretApikeyStorage:
            labelSelector:
              extauth: apikey
EOF


#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh
export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)

# Create an Ext-Auth Policy for product page
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: bookinfo-apiauth
  namespace: bookinfo-frontends
spec:
  applyToRoutes:
  - route:
      labels:
        apikeys: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: ${CLUSTER1}
    glooAuth:
      configs:
        - apiKeyAuth:
            headerName: api-key
            headersFromMetadataEntry:
              X-Solo-Plan:
                name: plan
                required: true
            k8sSecretApikeyStorage:
              labelSelector:
                auth: api-key
EOF
sleep 1
curl -k "https://${ENDPOINT_HTTPS_GW_CLUSTER1}/api/bookinfo" -I

# And create the api-key
export API_KEY_USER1=apikey1
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: user1
  namespace: bookinfo-frontends
  labels:
    auth: api-key
type: extauth.solo.io/apikey
data:
  api-key: YXBpa2V5MQ==
  user-id: dXNlcjE=
  user-email: dXNlcjFAc29sby5pbw==
  plan: Z29sZA==
EOF

#curl -k -H "api-key: ${API_KEY_USER1}" "https://${ENDPOINT_HTTPS_GW_CLUSTER1}/api/bookinfo"
http --verify=no https://${ENDPOINT_HTTPS_GW_CLUSTER1}/api/bookinfo "api-key:${API_KEY_USER1}"


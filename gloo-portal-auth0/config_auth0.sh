#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)
echo $ENDPOINT_HTTP_GW_CLUSTER1
echo $ENDPOINT_HTTPS_GW_CLUSTER1
echo $HOST_GW_CLUSTER1

export AUTH_URL="https://dev-0m4szpkvrtrxs4o1.us.auth0.com"
export AUTH_CLIENT="le9ATXSgcNsnGA0kaudt455MRnECYXoZ"
#export AUTH_SECRET="caNdLD7eKUjO5p6MpMvO3PCQ_lFu6C8Z3JycqFM5h1bCptzvO3kRGeLh3-Dye4fc"
export AUTH_SECRET="Z2pzEqmyTV_p-TRVWtSlAJxlvXZ9E3li6JPfjr4pswIVK3c1aueR_i3_ttV89Du0"

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: httpbin
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${AUTH_SECRET} | base64)
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    server:
      name: ext-auth-server
      namespace: gloo-mesh-addons
      cluster: ${CLUSTER1}
    glooAuth:
      configs:
      - oauth2:
          oidcAuthorizationCode:
            appUrl: "https://${ENDPOINT_HTTPS_GW_CLUSTER1}"
            callbackPath: /callback
            clientId: ${AUTH_CLIENT}
            clientSecretRef:
              name: oauth
              namespace: httpbin
            issuerUrl: ${AUTH_URL}
            session:
              failOnFetchFailure: true
              redis:
                cookieName: auth0-session
                options:
                  host: redis:6379
            scopes:
            - email
            headers:
              idTokenHeader: jwt
EOF


kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: httpbin
  namespace: httpbin
  labels:
    expose: "true"
spec:
  http:
    - name: httpbin
      labels:
        oauth: "true"
      matchers:
      - uri:
          exact: /get
      - uri:
          exact: /logout
      - uri:
          prefix: /callback
      forwardTo:
        destinations:
        - ref:
            name: not-in-mesh
            namespace: httpbin
            cluster: ${CLUSTER1}
          port:
            number: 8000
EOF
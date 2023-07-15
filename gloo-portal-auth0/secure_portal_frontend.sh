#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh
export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)


export AUTH_URL="https://dev-0m4szpkvrtrxs4o1.us.auth0.com"
export AUTH_CLIENT="Z4DuntUcgEv6YTNjU9DgfFlg4SLpVTIY"
#export AUTH_SECRET="caNdLD7eKUjO5p6MpMvO3PCQ_lFu6C8Z3JycqFM5h1bCptzvO3kRGeLh3-Dye4fc"
export AUTH_SECRET="yY_Fg3ndP7_Ue0i5_O1HhQNs85M8Mk1iTO2s7I72KGtLs-MJA8u-P4kkBv_JtNym"

kubectl --context ${CLUSTER1} apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth
  namespace: gloo-mesh-addons
type: extauth.solo.io/oauth
data:
  client-secret: $(echo -n ${AUTH_SECRET} | base64)
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ExtAuthPolicy
metadata:
  name: portal
  namespace: gloo-mesh-addons
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
            callbackPath: /portal-server/v1/login
            clientId: ${AUTH_CLIENT}
            clientSecretRef:
              name: oauth
              namespace: gloo-mesh-addons
            issuerUrl: "${AUTH_URL}"
            logoutPath: /portal-server/v1/logout
            session:
              failOnFetchFailure: true
              redis:
                cookieName: auth0-session
                options:
                  host: redis:6379
            scopes:
            - email
            headers:
              idTokenHeader: id_token
EOF
#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh
export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: portal-server
  namespace: gloo-mesh-addons
  labels:
    expose: "true"
spec:
  defaultDestination:
    ref:
      name: gloo-mesh-portal-server
      namespace: gloo-mesh-addons
      cluster: ${CLUSTER1}
    port:
      number: 8080
  http:
    - forwardTo:
        pathRewrite: /v1
      name: authn-api-and-usage-plans
      labels:
        oauth: "true"
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1
          headers:
            - name: Cookie
              #value: ".*?id_token=.*" # if not storing the id_token in Redis
              value: ".*?auth0-session=.*" # if storing the id_token in Redis
              regex: true
    - name: no-auth-apis
      forwardTo:
        pathRewrite: /v1
      labels:
        route: portal-api
      matchers:
        - uri:
            prefix: /portal-server/v1
EOF


# curl -k "https://${ENDPOINT_HTTPS_GW_CLUSTER1}/portal-server/v1/apis"
http --verify=no https://${ENDPOINT_HTTPS_GW_CLUSTER1}/portal-server/v1/apis

# Before you create the Portal, you bundle the APIs that you want to expose into a route table. Then, you prepare a usage plan to control access to your APIs by applying rate limiting and external auth policies to the routes in the route table.
# So RateLimit was created in file limit_productpage.sh which will create usege plans
# And RouteTable for product was created in file expose_productpage.sh
# ExtAuthPolicy was created in file secure_productpage.sh
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: apimanagement.gloo.solo.io/v2
kind: Portal
metadata:
  name: portal
  namespace: gloo-mesh-addons
spec:
  portalBackendSelectors:
    - selector:
        cluster: ${CLUSTER1}
        namespace: gloo-mesh-addons
  domains:
  - "*"
  usagePlans:
    - name: bronze
      displayName: "Bronze Plan"
      description: "A basic usage plan"
    - name: silver
      displayName: "Silver Plan"
      description: "A better usage plan"
    - name: gold
      displayName: "Gold Plan"
      description: "The best usage plan!"
  apis:
    - name: productpage-api
      namespace: bookinfo-frontends
      cluster: ${CLUSTER1}
EOF
sleep 3
http --verify=no https://$ENDPOINT_HTTPS_GW_CLUSTER1/portal-server/v1/apis

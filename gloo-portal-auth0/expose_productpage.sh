#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh
export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)

# First annotate the service productpage service
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-source=https://raw.githubusercontent.com/istio/istio/master/samples/bookinfo/swagger.yaml --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-pull-attempts="3" --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-retry-delay=5s --overwrite
kubectl --context ${CLUSTER1} -n bookinfo-frontends annotate service productpage gloo.solo.io/scrape-openapi-use-backoff="true" --overwrite

sleep 3
# Lets look at the apidoc
kubectl --context ${CLUSTER1} -n bookinfo-frontends get apidoc productpage-service -o yaml

sleep 3
# And expose the API by creating a route 
kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: productpage-api
  namespace: bookinfo-frontends
  labels:
    expose: "true"
    portal-users: "true"
spec:
  portalMetadata:
    title: BookInfo REST API
    description: REST API for the Bookinfo application
  http:
    - name: productpage-api
      matchers:
      - uri:
          prefix: /api/bookinfo
      labels:
        apikeys: "true"
        ratelimited: "true"
        api: "productpage"
      forwardTo:
        pathRewrite: /api/v1/products
        destinations:
          - ref:
              name: productpage
              namespace: bookinfo-frontends
            port:
              number: 9080
EOF

sleep 3
curl -k "https://${ENDPOINT_HTTPS_GW_CLUSTER1}/api/bookinfo"
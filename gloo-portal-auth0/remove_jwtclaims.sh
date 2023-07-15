#!/bin/bash
set -euo pipefail
IFS=$'\n\t'


export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)

export AUTH_URL="https://dev-0m4szpkvrtrxs4o1.us.auth0.com"
export AUTH_CLIENT="le9ATXSgcNsnGA0kaudt455MRnECYXoZ"
export AUTH_SECRET="Z2pzEqmyTV_p-TRVWtSlAJxlvXZ9E3li6JPfjr4pswIVK3c1aueR_i3_ttV89Du0"

export HOST_AUTH0="dev-0m4szpkvrtrxs4o1.us.auth0.com"
export PORT_AUTH0=443


kubectl delete --context ${CLUSTER1} -f - <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: JWTPolicy
metadata:
  name: httpbin
  namespace: httpbin
spec:
  applyToRoutes:
  - route:
      labels:
        oauth: "true"
  config:
    phase:
      postAuthz:
        priority: 1
    providers:
      auth0:
        issuer: https://${HOST_AUTH0}/
        tokenSource:
          headers:
          - name: jwt
        remote:
          url: https://${HOST_AUTH0}/.well-known/jwks.json
          destinationRef:
            kind: EXTERNAL_SERVICE
            ref:
              name: auth0
            port:
              number: ${PORT_AUTH0}
        claimsToHeaders:
        - claim: email
          header: X-Email
EOF

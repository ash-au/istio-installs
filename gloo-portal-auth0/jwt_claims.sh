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


# Due to this issue https://github.com/envoyproxy/envoy/issues/9984, we will need to specify tls setting
# Need to figure out how to do this with ExternalService

# kubectl apply --context ${CLUSTER1} -f - <<EOF
# apiVersion: networking.gloo.solo.io/v2
# kind: ExternalEndpoint
# metadata:
#   name: auth0
#   namespace: httpbin
#   labels:
#     host: auth0
# spec:
#   address: ${HOST_AUTH0}
#   ports:
#   - name: https
#     number: ${PORT_AUTH0}
# EOF

# kubectl apply --context ${CLUSTER1} -f - <<EOF
# apiVersion: networking.gloo.solo.io/v2
# kind: ExternalService
# metadata:
#   name: auth0
#   namespace: httpbin
#   labels:
#     expose: "true"
# spec:
#   hosts:
#   - ${HOST_AUTH0}
#   ports:
#   - name: http
#     number: ${PORT_AUTH0}
#     protocol: HTTPS
#   selector:
#     host: auth0
#   subjectAltNames:
#   - ${HOST_AUTH0}
# EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: ExternalService
metadata:
  name: auth0
  namespace: httpbin
  labels:
    expose: "true"
spec:
  hosts:
  - ${HOST_AUTH0}
  ports:
  - name: https
    number: 443
    protocol: HTTPS
  subjectAltNames:
  - ${HOST_AUTH0}
EOF

kubectl apply -f- <<EOF
apiVersion: security.policy.gloo.solo.io/v2
kind: ClientTLSPolicy
metadata:
  name: auth0
  namespace: istio-gateways
spec:
  applyToDestinations:
  - kind: EXTERNAL_SERVICE
    selector:
      namespace: httpbin
      labels:
        expose: "true"
    port:
      number: ${PORT_AUTH0}
  simple:
    config:
      sni: ${HOST_AUTH0}
EOF

kubectl apply --context ${CLUSTER1} -f - <<EOF
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
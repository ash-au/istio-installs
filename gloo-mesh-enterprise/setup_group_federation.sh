#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export GLOO_VERSION=2.2
export MGMT_CLUSTER=colima-mgmt
export REMOTE_CLUSTER1=colima-cluster1
export REMOTE_CLUSTER2=colima-cluster2
export MGMT_CONTEXT=colima-mgmt
export REMOTE_CONTEXT1=colima-cluster1
export REMOTE_CONTEXT2=colima-cluster2

export ISTIO_VERSION=1.16.1

# Create a Gloo Mesh root trust policy to ensure that services in cluster-1 securely communicate with the reviews service in cluster-2.
# The root trust policy sets up the domain and certificates to establish a shared trust model across multiple clusters in your service mesh.
kubectl apply --context $MGMT_CONTEXT -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust
  namespace: gloo-mesh
spec:
  config:
    autoRestartPods: true
    mgmtServerCa:
      generated: {}
EOF

# Create a virtual destination resource and define a unique hostname that in-mesh gateways can use to send requests to the reviews app. This virtual destination is configured to listen for incoming traffic on the internal-only, arbitrary hostname reviews.mesh.internal.com:8080. Note that this host value is different than the actual internal address that the reviews app can be reached by, because this host is an internal address that is used only by the gateways in your mesh.
kubectl apply --context $MGMT_CONTEXT -n bookinfo -f- <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: VirtualDestination
metadata:
  name: reviews-vd
  namespace: bookinfo
spec:
  hosts:
  # Arbitrary, internal-only hostname assigned to the endpoint
  - reviews.mesh.internal.com
  ports:
  - number: 8080
    protocol: HTTP
    targetPort:
      number: 9080
  services:
    - labels:
        app: reviews
EOF

# Create a routetable that defines how east-west requests within your mesh from productpage service to the reviews-vd virtual destination should be routed
# For hosts, specify reviews.bookinfo.svc.cluster.local, which is the actual internal hostname that the reviews app listens on
## Ths EW gateway does the work of routing requests for "reviews.bookinfo.svc.cluster.local" to "reviews.mesh.internal.com"
kubectl apply --context $MGMT_CONTEXT -n bookinfo -f- <<EOF
apiVersion: networking.gloo.solo.io/v2
kind: RouteTable
metadata:
  name: bookinfo-east-west
  namespace: bookinfo
spec:
  hosts:
    - 'reviews.bookinfo.svc.cluster.local'
  workloadSelectors:
    - selector:
        labels:
          app: productpage
  http:
    - name: reviews
      matchers:
      - uri:
          prefix: /reviews
      forwardTo:
        destinations:
          # Reference to the virtual destination that directs 15% of reviews traffic to reviews-v1 in cluster-1
          - ref:
              name: reviews-vd
            kind: VIRTUAL_DESTINATION
            port:
              number: 8080
            subset:
              version: v1
            weight: 33
          # Reference to the virtual destination that directs 10% of reviews traffic to reviews-v2 in cluster-1
          - ref:
              name: reviews-vd
            kind: VIRTUAL_DESTINATION
            port:
              number: 8080
            subset:
              version: v2
            weight: 33
          # Reference to the virtual destination that directs 75% of reviews traffic to reviews-v3 in cluster-2
          - ref:
              name: reviews-vd
            kind: VIRTUAL_DESTINATION
            port:
              number: 8080
            subset:
              version: v3
            weight: 34
EOF

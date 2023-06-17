#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export GLOO_VERSION="2.3.5"
export MGMT_CLUSTER=colima-mgmt
export REMOTE_CLUSTER1=colima-cluster1
export REMOTE_CLUSTER2=colima-cluster2
export MGMT_CONTEXT=colima-mgmt
export REMOTE_CONTEXT1=colima-cluster1
export REMOTE_CONTEXT2=colima-cluster2

export ISTIO_VERSION=1.17.2
export REPO=$GLOO_REPO_KEY
export ISTIO_IMAGE=1.17.2-solo
export REVISION=1-17-2

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

# Create a route table that defines how east-west requests within your mesh are routed from the productpage service to the reviews-vd virtual destination. When you apply this route table, requests from productpage to /reviews now route to one of the three reviews versions across clusters. The east-west gateway in your mesh does the work of taking requests made to the reviews.bookinfo.svc.cluster.local hostname and routing them to the reviews.mesh.internal.com virtual destination hostname that you specified in the previous step
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
          - ref:
              name: reviews-vd
            kind: VIRTUAL_DESTINATION
            port:
              number: 8080
      labels: 
        route: reviews
EOF

# Create a bookinfo workspace that spans across all your clusters, and includes only the bookinfo namespaces in each cluster. Note that you must create the workspace resource in the gloo-mesh namespace of the management cluster.
kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: bookinfo
  namespace: gloo-mesh
spec:
  workloadClusters:
    - name: '*'
      namespaces:
      - name: bookinfo
EOF

# Configure settings for bookinfo workspace
kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: bookinfo-settings
  namespace: bookinfo
spec:
  exportTo:
  - workspaces:  
    - name: istio-system
  options:
    serviceIsolation:
      enabled: true
    federation:
      enabled: false
      serviceSelector:
        - {}
      hostSuffix: 'global'
EOF

# Create an istio-system workspace that spans across clusters, and includes istio-system and gloo-mesh-gateways namespaces in each cluster.
# This ensures that the istiod control plane components as well as gateways are included in the same workspace
kubectl create ns istio-system --context $MGMT_CONTEXT
kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: istio-system
  namespace: gloo-mesh
spec:
  workloadClusters:
    - name: '*'
      namespaces:
      - name: istio-system
EOF

# And configure settings for it
kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: istio-system-settings
  namespace: istio-system
spec:
  importFrom:
  - workspaces:
    - name: bookinfo
EOF

# Modify the default workspace to become a management only workspace
kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: Workspace
metadata:
  name: $MGMT_CLUSTER
  namespace: gloo-mesh
spec:
  workloadClusters:
    - name: '$MGMT_CLUSTER'
      namespaces:
        - name: 'gloo-mesh'
EOF

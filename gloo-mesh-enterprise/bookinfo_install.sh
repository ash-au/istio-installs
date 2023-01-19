#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export GLOO_VERSION=2.1.4
export MGMT_CLUSTER=colima-mgmt
export REMOTE_CLUSTER1=colima-cluster1
export REMOTE_CLUSTER2=colima-cluster2
export MGMT_CONTEXT=colima-mgmt
export REMOTE_CONTEXT1=colima-cluster1
export REMOTE_CONTEXT2=colima-cluster2

export ISTIO_VERSION=1.16.1

function create_namespaces () {
  kubectl create ns bookinfo --context $MGMT_CONTEXT
  kubectl create ns istio-system --context $MGMT_CONTEXT
  kubectl create ns bookinfo --context $REMOTE_CONTEXT1
  kubectl create ns bookinfo --context $REMOTE_CONTEXT2
}

function setup_workspaces () {
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
      - name: gloo-mesh-gateways
EOF

kubectl apply --context $MGMT_CONTEXT -f- <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: WorkspaceSettings
metadata:
  name: istio-system-settings
  namespace: istio-system
spec:
  options:
    eastWestGateways:
    - selector:
        labels:
          istio: eastwestgateway
  importFrom:
  - workspaces:
    - name: bookinfo
EOF

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
}

function install_bookinfo () {
  # prepare the bookinfo namespace for Istio sidecar injection
  kubectl --context $REMOTE_CONTEXT1 label namespace bookinfo istio-injection=enabled
  # deploy bookinfo application components for all versions less than v3
  kubectl --context $REMOTE_CONTEXT1 -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)'
  # deploy all bookinfo service accounts
  kubectl --context $REMOTE_CONTEXT1 -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account'

  # prepare the bookinfo namespace for Istio sidecar injection
  kubectl --context $REMOTE_CONTEXT2 label namespace bookinfo istio-injection=enabled
  # deploy reviews and ratings services
  kubectl --context $REMOTE_CONTEXT2 -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'service in (reviews)'
  # deploy reviews-v3
  kubectl --context $REMOTE_CONTEXT2 -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (reviews),version in (v3)'
  # deploy ratings
  kubectl --context $REMOTE_CONTEXT2 -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (ratings)'
  # deploy reviews and ratings service accounts
  kubectl --context $REMOTE_CONTEXT2 -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account in (reviews, ratings)'
}

#create_namespaces
setup_workspaces
#install_bookinfo

sleep 10

kubectl --context $REMOTE_CONTEXT1 get pods -n bookinfo
kubectl --context $REMOTE_CONTEXT2 get pods -n bookinfo

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

export REPO=$GLOO_REPO_KEY
export ISTIO_IMAGE=1.17.2-solo
export REVISION=1-17-2

function install_istio_operator () {
  # Install istio control plane
  curl -0L https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/gloo-mesh/istio-install/gm-managed/gm-istiod.yaml > gm-istiod.yaml
  envsubst < gm-istiod.yaml > gm-istiod-values.yaml
  kubectl apply -f gm-istiod-values.yaml --context $MGMT_CONTEXT

  mv gm* ./tmp
}

function install_ew_gw () {
  # Install istio east-west gateway
  # Will have to change the default health check port for eastwest gateway, otherwise it will collide with the same port for ingress gateways
  curl -0L https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/gloo-mesh/istio-install/gm-managed/gm-ew-gateway.yaml > gm-ew-gateway.yaml
  envsubst < gm-ew-gateway.yaml > gm-ew-gateway-values.yaml
  gsed -i "s/15021/15022/g" gm-ew-gateway-values.yaml
  gsed -i "s/15443/16443/g" gm-ew-gateway-values.yaml
  kubectl apply -f gm-ew-gateway-values.yaml --context $MGMT_CONTEXT

  mv gm* ./tmp
}

function install_ingress_gw () {
  # Install Ingress gateways
  curl -0L https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/gloo-mesh/istio-install/gm-managed/gm-ingress-gateway.yaml > gm-ingress-gateway.yaml
  envsubst < gm-ingress-gateway.yaml > gm-ingress-gateway-values.yaml
  #gsed -i "s/15021/15023/g" gm-ingress-gateway-values.yaml
  kubectl apply -f gm-ingress-gateway-values.yaml --context $MGMT_CONTEXT

  mv gm* ./tmp
}

install_istio_operator
sleep 10
install_ew_gw
sleep 10
install_ingress_gw
sleep 100

kubectl get ns --context $REMOTE_CONTEXT1
kubectl get all -n gm-iop-1-17 --context $REMOTE_CONTEXT1
kubectl get all -n istio-system --context $REMOTE_CONTEXT1
kubectl get all -n gloo-mesh --context $REMOTE_CONTEXT1
kubectl get all -n gloo-mesh-gateways --context $REMOTE_CONTEXT1


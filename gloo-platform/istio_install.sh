#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

## Set environment variables
source env.sh

export REPO=$GLOO_REPO_KEY
export ISTIO_IMAGE=1.17.2-solo
export REVISION=1-17

function create_services() {
  # if [ ! $(kubectl --context ${CLUSTER} get ns | grep istio-gateways) ]; then
  #   kubectl --context ${CLUSTER} create ns istio-gateways
  # fi
  create_ns ${CLUSTER} istio-gateways
  kubectl --context ${CLUSTER} label namespace istio-gateways istio.io/rev=${REVISION} --overwrite
  # Deploy gloo mesh lifecycle manager
  kubectl apply --context ${CLUSTER} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: istio-ingressgateway
    istio: ingressgateway
  name: istio-ingressgateway
  namespace: istio-gateways
spec:
  ports:
  - name: http2
    port: 80
    protocol: TCP
    targetPort: 8080
  - name: https
    port: 443
    protocol: TCP
    targetPort: 8443
  selector:
    app: istio-ingressgateway
    istio: ingressgateway
    revision: ${REVISION}
  type: LoadBalancer
EOF

  kubectl apply --context ${CLUSTER} -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  labels:
    app: istio-ingressgateway
    istio: eastwestgateway
    topology.istio.io/network: ${CLUSTER}
  name: istio-eastwestgateway
  namespace: istio-gateways
spec:
  ports:
  - name: status-port
    port: 15021
    protocol: TCP
    targetPort: 15021
  - name: tls
    port: 15443
    protocol: TCP
    targetPort: 15443
  - name: https
    port: 16443
    protocol: TCP
    targetPort: 16443
  - name: tcp-istiod
    port: 15012
    protocol: TCP
    targetPort: 15012
  - name: tcp-webhook
    port: 15017
    protocol: TCP
    targetPort: 15017
  selector:
    app: istio-ingressgateway
    istio: eastwestgateway
    revision: ${REVISION}
    topology.istio.io/network: ${CLUSTER}
  type: LoadBalancer
EOF
}

export CLUSTER=$CLUSTER1
create_services
export CLUSTER=$CLUSTER2
create_services

function deploy_istio() {
  id=$1

  kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: IstioLifecycleManager
metadata:
  name: ${CLUSTER}-installation
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: ${CLUSTER}
        defaultRevision: true
      revision: ${REVISION}
      istioOperatorSpec:
        profile: minimal
        hub: ${REPO}
        tag: ${ISTIO_IMAGE}
        namespace: istio-system
        values:
          global:
            meshID: mesh${id}
            multiCluster:
              clusterName: ${CLUSTER}
            network: ${CLUSTER}
        meshConfig:
          accessLogFile: /dev/stdout
          defaultConfig:        
            proxyMetadata:
              ISTIO_META_DNS_CAPTURE: "true"
              ISTIO_META_DNS_AUTO_ALLOCATE: "true"
        components:
          pilot:
            k8s:
              env:
                - name: PILOT_ENABLE_K8S_SELECT_WORKLOAD_ENTRIES
                  value: "false"
          ingressGateways:
          - name: istio-ingressgateway
            enabled: false
EOF

  kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: ${CLUSTER}-ingress
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: ${CLUSTER}
        activeGateway: false
      gatewayRevision: ${REVISION}
      istioOperatorSpec:
        profile: empty
        hub: ${REPO}
        tag: ${ISTIO_IMAGE}
        values:
          gateways:
            istio-ingressgateway:
              customService: true
        components:
          ingressGateways:
            - name: istio-ingressgateway
              namespace: istio-gateways
              enabled: true
              label:
                istio: ingressgateway
---
apiVersion: admin.gloo.solo.io/v2
kind: GatewayLifecycleManager
metadata:
  name: ${CLUSTER}-eastwest
  namespace: gloo-mesh
spec:
  installations:
    - clusters:
      - name: ${CLUSTER}
        activeGateway: false
      gatewayRevision: ${REVISION}
      istioOperatorSpec:
        profile: empty
        hub: ${REPO}
        tag: ${ISTIO_IMAGE}
        values:
          gateways:
            istio-ingressgateway:
              customService: true
        components:
          ingressGateways:
            - name: istio-eastwestgateway
              namespace: istio-gateways
              enabled: true
              label:
                istio: eastwestgateway
                topology.istio.io/network: ${CLUSTER}
              k8s:
                env:
                  - name: ISTIO_META_ROUTER_MODE
                    value: "sni-dnat"
                  - name: ISTIO_META_REQUESTED_NETWORK_VIEW
                    value: ${CLUSTER}
EOF
}

export CLUSTER=$CLUSTER1
deploy_istio 1
export CLUSTER=$CLUSTER2
deploy_istio 2

export ENDPOINT_HTTP_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER1=$(kubectl --context ${CLUSTER1} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER1=$(echo ${ENDPOINT_HTTP_GW_CLUSTER1} | cut -d: -f1)
export ENDPOINT_HTTP_GW_CLUSTER2=$(kubectl --context ${CLUSTER2} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):80
export ENDPOINT_HTTPS_GW_CLUSTER2=$(kubectl --context ${CLUSTER2} -n istio-gateways get svc -l istio=ingressgateway -o jsonpath='{.items[0].status.loadBalancer.ingress[0].*}'):443
export HOST_GW_CLUSTER2=$(echo ${ENDPOINT_HTTP_GW_CLUSTER2} | cut -d: -f1)
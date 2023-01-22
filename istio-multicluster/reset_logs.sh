#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
export CTX_CLUSTER1=colima-cluster1
export CTX_CLUSTER2=colima-cluster2

hwpodname=$(kubectl --context="${CTX_CLUSTER1}" -n sample get pods -l app=helloworld -o jsonpath='{.items[0].metadata.name}')
echo $hwpodname
istioctl proxy-config log ${hwpodname}.sample -r --context ${CTX_CLUSTER1}

hwpodname=$(kubectl --context="${CTX_CLUSTER1}" -n istio-system get pods -l app=istio-eastwestgateway -o jsonpath='{.items[0].metadata.name}')
echo $hwpodname
istioctl proxy-config log ${hwpodname}.istio-system -r --context ${CTX_CLUSTER1}

hwpodname=$(kubectl --context="${CTX_CLUSTER2}" -n sample get pods -l app=helloworld -o jsonpath='{.items[0].metadata.name}')
echo $hwpodname
istioctl proxy-config log ${hwpodname}.sample -r --context ${CTX_CLUSTER2}

hwpodname=$(kubectl --context="${CTX_CLUSTER2}" -n istio-system get pods -l app=istio-eastwestgateway -o jsonpath='{.items[0].metadata.name}')
echo $hwpodname
istioctl proxy-config log ${hwpodname}.istio-system -r --context ${CTX_CLUSTER2}

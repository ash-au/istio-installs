#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Set environment variables
source env.sh

export ISTIO_VERSION=1.17.2
export REPO=$GLOO_REPO_KEY
export ISTIO_IMAGE=1.17.2-solo
# Get deployed istio revision
export REVISION=$(kubectl get pod -L app=istiod -n istio-system --context $REMOTE_CONTEXT1 -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
echo $REVISION

# Create Root Trust Policy to allow end-to-end mTLS cross cluster communication. This will ensure that certificates issues by istiod on each cluster are signed with intermediate certs which have a common root CA

kubectl apply --context ${MGMT} -f - <<EOF
apiVersion: admin.gloo.solo.io/v2
kind: RootTrustPolicy
metadata:
  name: root-trust-policy
  namespace: gloo-mesh
spec:
  config:
    mgmtServerCa:
      generated: {}
    autoRestartPods: true # Restarting pods automatically is NOT RECOMMENDED in Production
EOF

# When RootTrustPolicy is created, Gloo Mesh kicks off the process of unifying identities under a shared root
# First Gloo Mesh will create a Root Cert
# then GM will use agent on each cluster to create new key/cert pair that will form an ICA used by mesh on that cluster.
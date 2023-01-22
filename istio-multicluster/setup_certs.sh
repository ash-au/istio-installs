#!/bin/bash
set -euxo pipefail
IFS=$'\n\t'

# Set environment variables
export CTX_CLUSTER1=colima-cluster1
export CTX_CLUSTER2=colima-cluster2

# Clone istio repo if it does not exist. We'll use some scripts from istio tools
[ ! -d ./istio ] && git clone https://github.com/istio/istio.git

function generate_certs () {
    # Based on Plugin CA Certs istio documentation
    # https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/
    [ ! -d ./certs ] && mkdir -p certs
    pushd certs
    make -f ../istio/tools/certs/Makefile.selfsigned.mk root-ca
    make -f ../istio/tools/certs/Makefile.selfsigned.mk cluster1-cacerts
    make -f ../istio/tools/certs/Makefile.selfsigned.mk cluster2-cacerts
    popd
}

function setup_cert_incluster () {
    # This function depends on this
    set +e

    kubectl --context colima-$1 get ns istio-system
    [ $? -ne 0 ] && kubectl --context colima-$1 create ns istio-system
    
    kubectl --context colima-$1 get secrets cacerts -n istio-system
    [ $? -ne 0 ] && kubectl --context colima-$1 delete secret cacerts -n istio-system

    kubectl --context colima-$1 create secret generic cacerts -n istio-system \
        --from-file=./certs/$1/ca-cert.pem \
        --from-file=./certs/$1/ca-key.pem \
        --from-file=./certs/$1/root-cert.pem \
        --from-file=./certs/$1/cert-chain.pem 
}

generate_certs
setup_cert_incluster cluster1
setup_cert_incluster cluster2

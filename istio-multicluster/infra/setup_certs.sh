#!/bin/bash
set -euxo pipefail
IFS=$'\n\t'

# Set environment variables
export CTX_CLUSTER1=colima-cluster1
export CTX_CLUSTER2=colima-cluster2

# Clone istio repo if it does not exist. We'll use some scripts from istio tools
[ ! -d ./istio ] && git clone https://github.com/istio/istio.git

function generate_root_cert () {
    # Based on Plugin CA Certs istio documentation
    # https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/
    [ ! -d ./certs ] && mkdir -p certs
    pushd certs
    make -f ../istio/tools/certs/Makefile.selfsigned.mk root-ca
    popd
}

function generate_certs () {
    # Based on Plugin CA Certs istio documentation
    # https://istio.io/latest/docs/tasks/security/cert-management/plugin-ca-cert/
    [ ! -d ./certs ] && mkdir -p certs
    pushd certs
    make -f ../istio/tools/certs/Makefile.selfsigned.mk $1-cacerts
    #make -f ../istio/tools/certs/Makefile.selfsigned.mk cluster2-cacerts
    popd
}

function setup_cert_incluster () {
    # This function depends on this
    set +e
    kctx="colima-cluster$1"
    certdir="cluster$1"

    kubectl --context $kctx get ns istio-system
    [ $? -ne 0 ] && kubectl --context $kctx create ns istio-system
    
    kubectl --context $kctx get secrets cacerts -n istio-system
    [ $? -eq 0 ] && kubectl --context $kctx delete secret cacerts -n istio-system

    kubectl --context $kctx create secret generic cacerts -n istio-system \
        --from-file=./certs/$certdir/ca-cert.pem \
        --from-file=./certs/$certdir/ca-key.pem \
        --from-file=./certs/$certdir/root-cert.pem \
        --from-file=./certs/$certdir/cert-chain.pem 
}

generate_root_cert
generate_certs "cluster1"
generate_certs "cluster2"
setup_cert_incluster 1
setup_cert_incluster 2

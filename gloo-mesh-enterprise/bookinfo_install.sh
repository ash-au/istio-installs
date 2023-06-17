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
# Get deployed istio revision
export REVISION=$(kubectl get pod -L app=istiod -n istio-system --context $REMOTE_CONTEXT1 -o jsonpath='{.items[0].metadata.labels.istio\.io/rev}')
echo $REVISION

function install_bookinfo() {
    # Create bookinfo namespace in each cluster
  kubectl create ns bookinfo --context $MGMT_CONTEXT
  kubectl create ns bookinfo --context $REMOTE_CONTEXT1
  kubectl create ns bookinfo --context $REMOTE_CONTEXT2
  # Label workload cluster namespaces (bookinfo this case) for istio injection
  kubectl label ns bookinfo istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT1
  kubectl label ns bookinfo istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT2
  
  # CLUSTER 1
  # deploy bookinfo application components for all versions less than v3
  kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app,version notin (v3)' --context $REMOTE_CONTEXT1
  # deploy an updated product page with extra container utilities such as 'curl' and 'netcat'
  kubectl -n bookinfo apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/productpage-with-curl.yaml
  # deploy all bookinfo service accounts --context $REMOTE_CONTEXT1
  kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account' --context $REMOTE_CONTEXT1

  # CLUSTER 2
  # deploy reviews and ratings services
  kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'service in (reviews)' --context $REMOTE_CONTEXT2
  # deploy reviews-v3
  kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (reviews),version in (v3)' --context $REMOTE_CONTEXT2
  # deploy ratings
  kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'app in (ratings)' --context $REMOTE_CONTEXT2
  # deploy reviews and ratings service accounts
  kubectl -n bookinfo apply -f https://raw.githubusercontent.com/istio/istio/$ISTIO_VERSION/samples/bookinfo/platform/kube/bookinfo.yaml -l 'account in (reviews, ratings)' --context $REMOTE_CONTEXT2
}

function install_httpbin () {
  kubectl create ns httpbin --context $REMOTE_CONTEXT1
  kubectl label ns httpbin istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT1
  
  kubectl -n httpbin apply -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/httpbin.yaml --context $REMOTE_CONTEXT1

  slepe 5
  kubectl -n httpbin get pods --context $REMOTE_CONTEXT1
}

function install_helloworld () {
  kubectl create ns helloworld --context $REMOTE_CONTEXT1
  kubectl label ns helloworld istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT1

  kubectl create ns helloworld --context $REMOTE_CONTEXT2
  kubectl label ns helloworld istio.io/rev=$REVISION --overwrite=true --context $REMOTE_CONTEXT2

  # Helloworld v1 and v2 to cluster1
  kubectl -n helloworld apply --context $REMOTE_CONTEXT1 -l 'service=helloworld' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml 
  kubectl -n helloworld apply --context $REMOTE_CONTEXT1 -l 'app=helloworld,version in (v1, v2)' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml 

  # Helloworld v3 and v4 to cluster1
  kubectl -n helloworld apply --context $REMOTE_CONTEXT2 -l 'service=helloworld' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml 
  kubectl -n helloworld apply --context $REMOTE_CONTEXT2 -l 'app=helloworld,version in (v3, v4)' -f https://raw.githubusercontent.com/solo-io/gloo-mesh-use-cases/main/policy-demo/helloworld.yaml 

  sleep 5
  kubectl -n helloworld get pods --context $REMOTE_CONTEXT1
  kubectl -n helloworld get pods --context $REMOTE_CONTEXT2
}

function install_keycloack () {
  kubectl --context ${MGMT_CONTEXT} create namespace keycloak
  kubectl --context ${MGMT_CONTEXT} -n keycloak rollout status deploy/keycloak
  export ENDPOINT_KEYCLOAK=$(kubectl --context ${MGMT_CONTEXT} -n keycloak get service keycloak -o jsonpath='{.status.loadBalancer.ingress[0].*}'):8080
  export HOST_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK} | cut -d: -f1)
  export PORT_KEYCLOAK=$(echo ${ENDPOINT_KEYCLOAK} | cut -d: -f2)
  export KEYCLOAK_URL=http://${ENDPOINT_KEYCLOAK}/auth
  echo $KEYCLOAK_URL
  
  export KEYCLOAK_TOKEN=$(curl -d "client_id=admin-cli" -d "username=admin" -d "password=admin" -d "grant_type=password" "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" | jq -r .access_token)
  echo $KEYCLOAK_TOKEN

  # Create initial token to register the client
  read -r client token <<<$(curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"expiration": 0, "count": 1}' $KEYCLOAK_URL/admin/realms/master/clients-initial-access | jq -r '[.id, .token] | @tsv')
  export KEYCLOAK_CLIENT=${client}

  # Register the client
  read -r id secret <<<$(curl -X POST -d "{ \"clientId\": \"${KEYCLOAK_CLIENT}\" }" -H "Content-Type:application/json" -H "Authorization: bearer ${token}" ${KEYCLOAK_URL}/realms/master/clients-registrations/default| jq -r '[.id, .secret] | @tsv')
  export KEYCLOAK_SECRET=${secret}

  # Add allowed redirect URIs
  curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X PUT -H "Content-Type: application/json" -d '{"serviceAccountsEnabled": true, "directAccessGrantsEnabled": true, "authorizationServicesEnabled": true, "redirectUris": ["'https://${ENDPOINT_HTTPS_GW_CLUSTER1}'/callback"]}' $KEYCLOAK_URL/admin/realms/master/clients/${id}

  # Add the group attribute in the JWT token returned by Keycloak
  curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"name": "group", "protocol": "openid-connect", "protocolMapper": "oidc-usermodel-attribute-mapper", "config": {"claim.name": "group", "jsonType.label": "String", "user.attribute": "group", "id.token.claim": "true", "access.token.claim": "true"}}' $KEYCLOAK_URL/admin/realms/master/clients/${id}/protocol-mappers/models

  # Create first user
  curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user1", "email": "user1@example.com", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users

  # Create second user
  curl -H "Authorization: Bearer ${KEYCLOAK_TOKEN}" -X POST -H "Content-Type: application/json" -d '{"username": "user2", "email": "user2@solo.io", "enabled": true, "attributes": {"group": "users"}, "credentials": [{"type": "password", "value": "password", "temporary": false}]}' $KEYCLOAK_URL/admin/realms/master/users

}

install_bookinfo
sleep 10

# Verify that BookInfo pods have a status of running
kubectl --context $REMOTE_CONTEXT1 get pods -n bookinfo
kubectl --context $REMOTE_CONTEXT2 get pods -n bookinfo

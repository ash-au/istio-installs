
# Here cluster1 will act as client and mesh external service will be deployed on cluster2
# Set environment variables
CLUSTER1=colima-cluster1
CLUSTER2=colima-cluster2

# On the client side to initiate the E/W request
kubectl --context ${CLUSTER1} apply -f -<<EOF
# On the client side to initiate the E/W request
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: access-out-of-mesh-service
  namespace: bookinfo-backends
spec:
  addresses:
    - 243.249.227.32
  exportTo:
    - bookinfo-backends
    - bookinfo-frontends
    - istio-system
  hosts:
    - out-of-mesh-service.gloo-mesh.global
  location: MESH_INTERNAL
  ports:
    - name: http-80
      number: 80
      protocol: HTTP
      targetPort: 80
  resolution: DNS
  workloadSelector:
    labels:
      app: out-of-mesh
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: access-out-of-mesh-service
  namespace: bookinfo-backends
spec:
  host: out-of-mesh-service.gloo-mesh.global
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
      # Need to set this to override the SNI otherwise it will be auto generated
      sni: out-of-mesh-service.gloo-mesh.global
---
apiVersion: networking.istio.io/v1beta1
kind: WorkloadEntry
metadata:
  name: access-out-of-mesh-service
  namespace: bookinfo-backends
  labels:
    app: out-of-mesh
spec:
  # Address of the destination E/W gateway
  address: 192.168.106.8
  labels:
    app: out-of-mesh
    security.istio.io/tlsMode: istio
  ports:
    http-80: 15443
EOF
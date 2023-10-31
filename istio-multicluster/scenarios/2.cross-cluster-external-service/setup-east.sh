
# Set environment variables
CLUSTER1=colima-cluster1
CLUSTER2=colima-cluster2


kubectl --context ${CLUSTER2} apply -f -<<EOF
apiVersion: networking.istio.io/v1beta1
kind: Gateway
metadata:
  name: east-west-out-of-mesh-mtls-gw
  namespace: istio-system
spec:
  selector:
    app: istio-eastwestgateway
    istio: eastwestgateway
  servers:
    - hosts:
        - out-of-mesh-service.gloo-mesh.global
      name: east-west-out-of-mesh-gw
      port:
        name: https
        number: 15443
        protocol: HTTPS
      tls:
        mode: ISTIO_MUTUAL
---
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: out-of-mesh
  namespace: istio-system
spec:
  hosts:
    - out-of-mesh-service.gloo-mesh.global
  gateways:
    - east-west-out-of-mesh-mtls-gw
  http:
    - match:
        - port: 15443
      rewrite:
        authority: httpbin.httpbin.svc.cluster.local 
      route:
        # Destination at this point can be anything. This showing it being routed to an external service
        - destination:
            host: httpbin.httpbin.svc.cluster.local
            port:
              number: 8000
---
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin-out-of-mesh-service
  namespace: istio-system
spec:
  host: httpbin.httpbin.svc.cluster.local
  trafficPolicy:
    # We dont want TLS origination. Because httpbin only accepts plain-text
    tls:
      mode: DISABLE
EOF
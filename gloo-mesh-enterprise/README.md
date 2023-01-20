# Gloo Mesh Install

1. mesh_install.sh to create clusters and mgmt plane
2. istio_install.sh to deploy istio
3. bookinfo_install.sh to deploy bookinfo
4. setup_group_federation.sh to setup cross cluster federation


## Gloo Mesh Federation
Gloo Platform does this to federate the resources
1. Gloo Platform federates Gloo and Kubernetes in **each workspace**. As part of discovery, Gloo identifies the workspace settings to decide which resources should be available
2. Translates the Gloo and Kubernetes resources into underlying Istio resources such as virtual services, service entries and envoy filters.
3. Copies the underlying istio resources in each cluster and namespace of that the Gloo or Kubernetes resource belongs to.

Workspaces can span clusters, federation makes the resource available across clusters. For more details on the discovery

### Relay Architecture (resource discovery)
Each relay agent performs mesh discovery for the cluster that it is dployed to and then constructs a snapshot of the actual state of discovered entities in the workload cluster, including
* Discovery Resourcs, such as k8 services, deployments, replicasets, and statefulsets. The mgmt server translates discovered resources into istio resources and displays them in the proxies. Discovery selectors are honored for resources in snapshot. Discovery includes all services in namespaces that istio discovers
* Gloo Custom Resources, mgmt server translates them into istio resources
* Istio resources, including
  * Istio resources that mgmt server automatically translates from Gloo resources and writed back to the workload cluster. 
  * Any manually created istio resources
* Internal resources, including
  * `Mesh` resources
  * `Gateway` resources 
  * `IssuedCertificate` & `CertificateRequest` resources, which are used in internal multi-step workflows that involve both agent and mgmt server

![Relay Agent Architecture](https://docs.solo.io/gloo-mesh-enterprise/main/img/arch-relay3-user-apply.svg)


### Types of federation
Gloo can federate ungrouped services for an entire `workspace`, or groupings of services that you define in select Gloo customer resource (?). 
#### **Ungrouped workspace-level federation**
Resource: WorkspaceSetting
Use Case: Simple testing of intial migration
Federation for a workspace can be federated in workspace settings. Gloo witll create separate service entries in each cluster for the k8s services of the workspace. 

Destinations are not grouped so not possible to take advantage of all routing capabilities of Gloo resources like attaching policies to all service entries at once. 

You can configure federation and east-west gateways for multicluster traffic in `WorkspaceSettings`. Gloo will then federate each service to every namespace in the workspace as well as any workspace that imports the service.

As part of federation process, Gloo creates Istio service entries in each cluster for kubernetes services in a workspace with unique hostname in the format `<service_name>.<namsspace>.svc.<cluser_name>.<host_suffix>`.
Then you can route to the federated host directly or by creating a route table for that host.

`VirtualDestination` can be used setup failover instead of workspace-level federation.


#### **Grouped, resource-specific federation**

When you create a `VirtualDestination` or `ExternalService`, Gloo groups together and federates the backing services. Federation makes the service, the resources represents, available in each namespace within the workspace, across clusters and even other workspaces if you set up importing and exporting.
This enables consistent ingress control for the routes that the route table select.


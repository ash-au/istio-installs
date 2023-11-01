## Scenaro 1 - Standard apps install and verification

Make sure to change kubernetes context names before executing files

1. install\_sample_apps.sh to install sample applications
2. verify_install.sh to ensure that everything is working fine

## Scenario 2 - To test service outside the cluster
This scenario is represented in this architecture
![](2.cross-cluster-external-service/arch.png)


After step 3 above

3. scenarios/bookinfo_install.sh to install bookinfo on both clusters
4. scenarios/install-httpbin.sh outside the mesh on cluster2 or east cluster
5. scenarios/setup-east.sh
6. scenarios/setup-west.sh

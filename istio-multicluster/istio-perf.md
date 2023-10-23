# Istio Performance Tuning

This article attempts to consolidate isito performance tuning information starting with istio's performance and scalability information 



Specifically focussing on these areas
1. Namespace isolation will have impact on sidecar memory consumption. TODO: How to?
2. Disable zipkin tracing or reduce the sampling rate. TODO: How to?
3. Simplify the access log format. TODO: How to?
4. Disable Envoy's access log service. TODO: How to?
5. Enable eBPF. This will improve latency by approximately 12-14% . TODO: How to?



Additional information
- Istio's performance and scalibility information https://istio.io/latest/docs/ops/deployment/performance-and-scalability/
- https://www.solo.io/blog/envoy-at-scale-with-gloo-edge/
- Tetrate has some information on their blog here https://tetrate.io/blog/performance-optimization-for-istio

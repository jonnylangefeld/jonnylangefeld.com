---
layout: post
title:  "Ingress Hardening at Cruise"
categories: []
tags:
- kubernetes
- cncf
- clusters
- infrastructure
- ingress
- tips & tricks
status: publish
type: post
published: true
meta: {}
---

This is a cross-post from the [original post on LinkedIn](https://www.linkedin.com/pulse/ingress-hardening-cruise-jonny-langefeld/).

At Cruise we have a requirement for a highly available central ingress service that can be used by all service owners alike. Our ingress solution of choice is a self managed istio setup. We are choosing istio because we make use of both, the ingress and service mesh components of it.
We started off with an in-cluster ingress service. However, company wide outages started piling up due to the fact that a Kubernetes service with type `LoadBalancer` on [GCP can only have 250](https://cloud.google.com/load-balancing/docs/quotas#backend_services) ([1,000 on Azure](https://github.com/MicrosoftDocs/azure-docs/blob/248f40dfd7dff792895bf0d51c1c281e7169e716/includes/azure-virtual-network-limits.md#load-balancer-limits)) backends on the provisioned cloud load balancer for internal load balancing. When a kubernetes service with type `LoadBalancer` is created on a cluster, the cloud native service controller provisions a cloud vendor specific internal L4 load balancer resource. This load balancer pulls a random subset of 250 nodes in the cluster as backends. If the traffic handling `istio-ingressgateway` pods happened to be scheduled outside this subset and `externalTrafficPolicy` is set to `Local` on the Kubernetes service, then all incoming cluster traffic is blocked. This can be technically circumvented by setting `externalTrafficPolicy` to `Cluster` which means that incoming traffic can hit a random node and gets forwarded to the correct target node that runs the ingress pod by the `kube-proxy` daemonset in the `kube-system` namespace. However, besides the fact that it’s an extra unnecessary network hop, this also does not preserve the source IP of the caller. This is explained in more detail in the blog post [“Kubernetes: The client source IP preservation dilemma”](https://elsesiy.com/blog/kubernetes-client-source-ip-dilemma). While changing the  `externalTrafficPolicy` to `Cluster` might work for some services, this was not acceptable for us as our offering is a central service used by many other services at Cruise, some of which have the requirement to keep the source IP.

The interim solution to this was to run the `istio-ingressgateway` on self managed VMs with the `VirtualService` resources on target Kubernetes clusters as input for the routing configuration. This resulted in a complex terraform module with 26 individual resources that contained many cloud resources like

<!--more-->

* Instance template
* Instance group manager
* Autoscaler
* Firewall
* IP addresses
* Forwarding rules
* Health checks

We essentially had to recreate a Kubernetes `Deployment` and `Service`. Since this was running outside the cluster we had to prepare the VMs with a running docker daemon, authentication to our internal container registry and a monitoring agent, which was done via a startup script. All in redundancy to what a Kubernetes cluster would have offered. While this setup mitigated the problem at hand, the complexity of this setup triggered misconfigurations during upgrades. Also the startup script would sometimes fail due to external dependencies potentially resulting in ingress outages.

An additional contributing factor to complexity was that some larger clusters ran the out-of-cluster solution described above, while some smaller, highly automated clusters ran the in-cluster solution. The two solutions were rolled out through different processes (Terraform vs Google Config Connector), requiring separate maintenance and version upgrades. All desired config changes had to be made to both solutions. The path forward was clear: We wanted to consolidate on the in-cluster solution that allows for more automation, less duplication of Kubernetes concepts, single source of truth for configurations, less created cloud native resources (only a dedicated IP address is needed for the in-cluster service) and overall easier maintainability of the service while still working on clusters with more than 250 nodes without sacrificing the source IP.

### The Path Forward

For this to be possible we worked closely together with the responsible teams at Google Cloud Platform to deliver features like [Container Native Load Balancing](https://cloud.google.com/kubernetes-engine/docs/how-to/container-native-load-balancing), [ILB Subsetting](https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing#subsetting) and removing unhealthy backends from cloud load balancers as quickly as possible. We provide feedback in multiple iterations of the outcome of our load tests upon which the Google teams implemented further improvements.

Internally we hardened the in-cluster setup with the following:

* Dedicated node pools for ingress pods.
* Allow only one pod per node via anti affinity rules to prevent connection overloading on node level.
* Set the amount of ingress replicas to the `amount of zones + 2`. This means that at least one zone has more than one replica. Because the GCP scaling API only allows us to scale by 1 node per zone at a time, it could happen that all nodes get replaced at once if we have only 1 node per zone. With this formula we guarantee that there are always at least 2 running pods.
* Set [`PodDisruptionBudget`](https://kubernetes.io/docs/tasks/run-application/configure-pdb/) that requires less healthy pods then desired replicas in the deployment to not block node drains
* Set [`HorizontalPodAutoscalers`](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) based on memory and CPU usage.
* Add a [`PreStop` lifecycle hook](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/) that sleeps for 120 seconds. This is that existing connections are untouched upon pod termination and can run for a full 2 minutes before a `SIGTERM` is received.
* Set `terminationGracePeriodSeconds` to 180 seconds to give connections an additional minute to gracefully terminate long running connections after the `SIGTERM` is received.
* Tweak [liveness and readiness probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/). Liveness probes have a higher failure threshold to prevent frequently restarting pods, while readiness probes have a lower failure threshold to not route traffic while the pod is not healthy.
* Lower resource requests while raising resource limits. This is to achieve a higher likelihood of scheduling on a cramped node while we allow this pod to use a lot of resources if necessary.

### Migration

Cluster traffic at Cruise grew along with criticality as we now have fully driverless vehicles on the roads. So the migration from out-of-cluster traffic to in-cluster had to be carefully planned and executed. We specifically had to migrate 3 critical, large clusters across 3 environments (which makes it 9 migrations). We deployed both the in-cluster and out-of-cluster solution in parallel, both with L4 load balancers and a dedicated IP. At this point only an A record swap for our ingress domain was necessary. Client domains use CNAMEs from their service names to our centrally offered ingress domain, so there was no client side change necessary. We carefully swapped the A records slowly cluster by cluster, environment by environment, while closely monitoring the metrics. Our preparation has paid off and we rerouted 100% of all mission critical traffic at Cruise without a blip and without any customer experiencing a downtime.

To learn more about technical challenges we’re tackling at Cruise infrastructure, visit [getcruise.com/careers](https://getcruise.com/careers).

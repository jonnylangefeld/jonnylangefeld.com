---
layout: post
title:  "The Kubernetes Discovery Cache: Blessing and Curse"
categories: []
tags:
- kubernetes
- go
- cncf
- discovery
- sig
- api
- controllers
- operators
status: publish
type: post
published: true
meta: {}
---
This blog post explores the idea of using Kubernetes as a generic platform for managing declarative APIs and asynchronous controllers beyond its ability of a container orchestrator and how the discovery cache plays into that consideration.

It all started for me with a tweet by Bryan Liles ([VP, Principal Engineer at VMWare](https://www.linkedin.com/in/bryanliles/)) almost a year ago, of which Tim Hockin ([Principal Software Engineer at Google & Founder of Kubernetes](https://www.linkedin.com/in/tim-hockin-6501072/)) was [affirmative](https://twitter.com/thockin/status/1346313102430670851):

<blockquote class="twitter-tweet tw-align-center"><p lang="en" dir="ltr">I often think about Kubernetes and how it rubs people the wrong way. There are lots of opinions about k8s as a container orchestrator, but the real win (and why I think it is great) is the core concept: Platform for managing declarative APIs. Infra APIs have never been better.</p>&mdash; Bryan Liles (@bryanl) <a href="https://twitter.com/bryanl/status/1346125863419568129">January 4, 2021</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

I thought this was so true. Kubernetes embodies a lot of principles of the perfect API. Every resource has a group, a version and a kind, it offers extensible metadata, a spec for input data (desired state) and a status of the resource (actual state). What else do you wish for? Also the core Kubernetes controllers like the deployment controller, pod controller, autoscaler controller and persistent volume claim controller are perfect examples of asynchronous controller patterns that take a desired state as input and achieve that state through reconciliation with eventual consistency. The fact that this functionality is exposed to Kubernetes users via custom resource definitions (CRDs) makes the entire platform incredibly extensible.

Controllers like [crossplane.io](https://crossplane.io), [GCP Config Connector](https://github.com/GoogleCloudPlatform/k8s-config-connector) or [Azure Service Operator](https://github.com/Azure/azure-service-operator) have adopted the pattern to a large degree and install 100s, if not 1,000s of CRDs on clusters. However that doesn't come without its drawbacks...

<!--more-->

These draw backs aren't due to high load on the Kubernetes API server. In fact, that actually has a pretty robust and advanced rate limiting mechanism through the [priority and fairness](https://kubernetes.io/docs/concepts/cluster-administration/flow-control) design, that most likely will ensure that the API server doesn't crash even if a lot of requests are made.

However, installing many CRDs on a cluster can impact the [OpenAPI spec publishing](https://github.com/crossplane/crossplane/issues/2649), as well as the [discovery cache creation](https://github.com/kubernetes/kubectl/issues/1126). OpenAPI spec creation for many CRDs has [recently been fixed](https://github.com/kubernetes/kube-openapi/pull/251) through implementing lazy marshalling. While an interesting concept, this could be the topic of another blog post as in this one we are focusing on the latter one: discovery cache creation.

It started with more and more log message like the following when using regular `kubectl` commands:

```text
Waited for 1.140352693s due to client-side throttling, not priority and fairness, request: GET:https://10.212.0.242/apis/storage.k8s.io/v1beta1?timeout=32s
```

What's interesting is that that immediately excludes the priority and fairness mechanism described earlier and talks about 'client-side throttling'. My first instinct however was just to suppress the log line because I hadn't asked `kubectl` to print any debug logs for instance with `-v 1`. I found [this issue on kubernetes/kubernetes](https://github.com/kubernetes/kubernetes/pull/101634) pursuing the same goal and gave it a thumbs up in the hope to just suppress this annoying log message that you couldn't switch off. However as the discussion on that PR progressed and specifically [this comment](https://github.com/kubernetes/kubernetes/pull/101634#issuecomment-840691885), saying that "this log message saves 10 hours of debugging for every hour it costs someone trying to hide it", got me thinking that there must be more to the story and that just not printing the log message is not going to be the right approach. The PR eventually was closed without merging.

This lead me down the rabbit hole of looking at some `kubectl` debug logs and I found that a simple request for pods via `kubectl get pod -v 8` let to 100s of `GET` requests à la

```text
GET https://<host>/apis/dns.cnrm.cloud.google.com/v1beta1?timeout=32s
GET https://<host>/apis/templates.gatekeeper.sh/v1alpha1?timeout=32s
GET https://<host>/apis/firestore.cnrm.cloud.google.com/v1beta1?timeout=32s
```

This was on a cluster with already a few controllers installed, like the [GCP Config Connector](https://github.com/GoogleCloudPlatform/k8s-config-connector) or [Gatekeeper](https://github.com/open-policy-agent/gatekeeper). I noticed the group versions like `dns.cnrm.cloud.google.com/v1beta1` or `templates.gatekeeper.sh` in the debug output relating to those controllers even though I just simply queried for pods.

It occurred to me that these many `GET` requests would ultimately trigger the client-side rate limiting and that those `GET` requests were made to populate the discovery cache. [This reddit post](https://www.reddit.com/r/kubernetes/comments/bpfi48/comment/enuhn5v/?utm_source=share&utm_medium=web2x&context=3) helped me understand this behavior majorly and I also [reported this back on the original Kubernetes issue regarding those ominous log messages](https://github.com/kubernetes/kubernetes/pull/101634#issuecomment-933851060), which triggered the community to [raise a new issue](https://github.com/kubernetes/kubernetes/issues/105489) all together, regarding a fix for client side throttling due to discovery caching.

### The Discovery Cache

But why do we even need 100s of requests in the background for simply querying pods via `kubectl get pods`? That is thanks to the ingenious idea of the [Kubernetes discovery client](https://github.com/kubernetes/client-go/blob/master/discovery/discovery_client.go). That allows us to run all variations of `kubectl get po`, `kubectl get pod`, `kubectl get pods` and the Kubernetes API server always knows what we want. That becomes even more useful for resources that implement categories, which can trigger a `kubectl get <category>` to return various different kinds of resources.

The way this works is to translate any of those `kubectl` commands to the actual API server endpoint like

```text
GET https://<host>/api/v1/namespaces/<current namespace>/pods
```

You see that `kubectl` has to fill in the `<current namespace>` and query for `/pods` (and not for `/po` or `/pod`). It gets the `<current namespace>` through the `$KUBECONFIG` (which is usually stored at `~/.kube/config`), or falls back to `default`. It is also possible to query pods of all namespaces at once. The way `kubectl` resolves a request for `po` or `pod` to the final endpoint `/pods` is through a local cache stored at `~/.kube/cache/discovery/<host>/v1/serverresources.json`. In fact, there is a `serverresources.json` file for every group version of resources installed on the cluster. If you look at the entry for pods you will find something like

```json
{
  "name": "pods",
  "singularName": "",
  "namespaced": true,
  "kind": "Pod",
  "verbs": [...],
  "shortNames": [
    "po"
  ],
  "categories": [
    "all"
  ]
}
```

With this reference `kubectl` knows that a request for `pods`, `pod` (which is the `kind`), `po` (which is in the `shortNames` array) or `all` (which is in the `categories`) should result in the final request for `/pods`.

`kubectl` creates the `serverresources.json` for every group version either if the requested kind is not present in any of the cached `serverresources.json` files, or if the cache is invalid. The cache invalidates itself [every 10 minutes](https://github.com/kubernetes/kubernetes/blob/0fb71846df9babb6012a7fce22e2533e9d795baa/staging/src/k8s.io/cli-runtime/pkg/genericclioptions/config_flags.go#L253).

That means in those cases `kubectl` has to make a request to every group version on the cluster to populate the cache again, which results in those 100s of `GET` requests described earlier, and those again trigger the client-side rate limiting. On large clusters with many CRDs `kubectl get` requests can often easily take up to a minute to run through all these requests plus pausing for the rate limiting. Thus it is advisable to not let your CRD count grow limitless. In fact, the scale targets for GA of custom resource definitions is set to 500 in the [Kubernetes enhancement repo](https://github.com/kubernetes/enhancements/tree/master/keps/sig-api-machinery/95-custom-resource-definitions#scale-targets-for-ga).

So while the discovery cache is actually adding usability to Kubernetes, it also is the limiting factor for extending the platform with custom controllers and CRDs.

### Scaling

Especially the crossplane community has a vested interest in unlocking this limitation because crossplane's entire design philosophy is built upon the idea to create CRDs for every object in the real world and reconciling it through controllers. But it will also be important for other controllers introducing many CRDs like the [GCP Config Connector](https://github.com/GoogleCloudPlatform/k8s-config-connector) or the [Azure Service Operator](https://github.com/Azure/azure-service-operator).

For now the [aforementioned issue on kubernetes/kubernetes](https://github.com/kubernetes/kubernetes/issues/105489) based on my user report regarding many `GET` requests after a simple `kubectl get pods` triggered a set of PRs ([1](https://github.com/kubernetes/kubernetes/pull/105520), [2](https://github.com/kubernetes/kubernetes/pull/107131)) aimed at increasing the rate limits during discovery. However, this is just kicking the can down the road (or as [@liggitt correctly put it](https://github.com/kubernetes/kubernetes/pull/105520#discussion_r723535829) the 'kubernetes equivalent of the debt ceiling') as it's not solving the underlying issue of many unnecessary `GET` requests, but merely not rate limiting as often, which still means a strain on resources and that we will run into the same issue again at a later point in time with even more CRDs. While `kubectl` still performs 100s of `GET` requests, at least the total run time is [roughly cut in half](https://github.com/kubernetes/kubernetes/pull/107131#issue-1084329062) as there is no additional rate limiting anymore with the fixes.

I also raised [a separate issue](https://github.com/kubernetes/kubernetes/issues/107130) to challenge the status quo of invalidating the cache every 10 minutes by increasing that default and also to make this timeout configurable (rather than [hard coding it](https://github.com/kubernetes/kubernetes/blob/0fb71846df9babb6012a7fce22e2533e9d795baa/staging/src/k8s.io/cli-runtime/pkg/genericclioptions/config_flags.go#L253)). But again, this just raises limits and doesn't actually minimize the amount of unused `GET` requests.

So the real, lasting solution might be a bit more involved and require to only `GET` the `serverresources.json` of a group version that is actually requested once the cache got invalid or isn't present. So a request for `kubectl get pods` would only populate the `~/.kube/cache/discovery/<host>/v1/serverresources.json` file (because `pods` are in group `""` and version `v1`) rather than every single group version. This would eliminate all unnecessary requests for unrelated resources and majorly reduce the total amount of `GET` requests. This solution would also require a server side change to offer and endpoint that reveals all potential group versions for a given kind.

If you have other ideas to solve this, feel free to reach out [@jonnylangefeld](https://twitter.com/jonnylangefeld) on twitter to discuss or file an issue directly on [kubernetes/kubernetes](https://github.com/kubernetes/kubernetes/issues/new/choose).

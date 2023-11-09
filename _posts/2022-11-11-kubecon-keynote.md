---
layout: post
title: "KubeCon Keynote"
categories: []
tags:
  - kubernetes
  - cncf
  - clusters
  - infrastructure
  - kubecon
status: publish
type: post
published: true
meta: {}
---

A few weeks ago I had the honor to give a keynote at KubeCon North America 2022. I talked about the challenges of running Kubernetes clusters at scale and how
we at Cruise are solving them. The video is now available on YouTube:

<iframe width="100%" height="405" src="https://www.youtube.com/embed/DWFzChxXXrU?si=zL7raeLnI1S25MlT&amp;start=1941" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

In the keynote I highlighted how we are using Kubernetes operators to majorly increase the automation of our cluster provisioning process. The GCP/AKS/EKS API
call to actually create the cluster itself is just the tip of the iceberg of all the things that need to happen to get a cluster ready for production.

<img src="assets/posts/kubecon.jpg" width="100%" align="middle" />

We utilize a tree of controllers and the power of custom resource definitions to extend the declarative Kubernetes API to our needs.

When it took an engineer a whole week to provision a cluster manually, it now is a matter of one API call to provision a cluster with the same amount of
resources and the actual provisioning process happens asynchronously and hands-off in the background.

More details about our cluster provisioning process can be found in my previous blog post
[Herd Your Clusters Like Cattle: How We Automated our Clusters](/blog/herd-your-clusters-like-cattle).

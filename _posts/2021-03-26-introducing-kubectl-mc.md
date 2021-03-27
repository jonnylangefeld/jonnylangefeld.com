---
layout: post
title:  "Introducing kubectl mc"
categories: []
tags:
- kubernetes
- addon
- krew
- multi cluster
- cli
- tool
- go
status: publish
type: post
published: true
meta: {}
---
If you work at a company or organization that maintains multiple Kubernetes clusters it is fairly common to connect to multiple different kubernetes clusters throughout your day. And sometimes you want to execute a command against multiple clusters at once. For instance to get the status of a deployment across all `staging` clusters. You could run your `kubectl` command in a bash loop. That does not only require some bash logic, but also it'll take a while to get your results because every loop iteration is an individual API round trip executed successively.

[`kubectl mc`](https://github.com/jonnylangefeld/kubectl-mc) (short for multi cluster) supports this workflow and significantly reduces the return time by executing the necessary API requests in parallel go routines.

It's doing that by creating a wait group channel with [`n` max entries](https://github.com/jonnylangefeld/kubectl-mc/blob/v1.0.1/pkg/mc/mc.go#L143-L146). 
The max amount of entries can be configured with the `-p` flag. It then iterates through a list of contexts that matched
a regex, given with the `-r` flag, and executes the given `kubectl` command in [parallel go routines](https://github.com/jonnylangefeld/kubectl-mc/blob/v1.0.1/pkg/mc/mc.go#L167).

### Installation

While you can install the binary via `go get github.com/jonnylangefeld/kubectl-mc`, it is recommended to use the [`krew`](https://krew.sigs.k8s.io/)
package manager. Check out [their website for installation](https://krew.sigs.k8s.io/docs/user-guide/setup/install/).  

Run `krew install mc` to install mc. 

In both cases a binary named `kubectl-mc` is made available on your path. `kubectl` automatically identifies binaries
named `kubectl-*` and makes them available as `kubectl` plugin. So you can use it via `kubectl mc`.

# Usage

Run `kubectl mc` for help and examples. Here is one to begin with:

<!--more-->

```bash
$ kubectl mc --regex kind -- get pods -n kube-system

kind-kind
---------
NAME                                         READY   STATUS    RESTARTS   AGE
coredns-f9fd979d6-q7gnm                      1/1     Running   0          99m
coredns-f9fd979d6-zd4jn                      1/1     Running   0          99m
etcd-kind-control-plane                      1/1     Running   0          99m
kindnet-8qd8p                                1/1     Running   0          99m
kube-apiserver-kind-control-plane            1/1     Running   0          99m
kube-controller-manager-kind-control-plane   1/1     Running   0          99m
kube-proxy-nb55k                             1/1     Running   0          99m
kube-scheduler-kind-control-plane            1/1     Running   0          99m

kind-another-kind-cluster
-------------------------
NAME                                                         READY   STATUS    RESTARTS   AGE
coredns-f9fd979d6-l2xdb                                      1/1     Running   0          91s
coredns-f9fd979d6-m99fx                                      1/1     Running   0          91s
etcd-another-kind-cluster-control-plane                      1/1     Running   0          92s
kindnet-jlrqg                                                1/1     Running   0          91s
kube-apiserver-another-kind-cluster-control-plane            1/1     Running   0          92s
kube-controller-manager-another-kind-cluster-control-plane   1/1     Running   0          92s
kube-proxy-kq2tr                                             1/1     Running   0          91s
kube-scheduler-another-kind-cluster-control-plane            1/1     Running   0          92s
```

As you can see, each context that matched the regex `kind` executes the `kubectl` command indicated through the `--`
surrounded by spaces.

Apart from the plain standard `kubectl` output, you can also have everything in `json` or `yaml` output using the
`--output` flag. Here is an example of `json` output piped into `jq` to run a query which prints the context and the pod
name for each pod:

```bash
$ kubectl mc --regex kind --output json -- get pods -n kube-system | jq 'keys[] as $k | "\($k) \(.[$k] | .items[].metadata.name)" '
"kind-another-kind-cluster coredns-66bff467f8-6xp9m"
"kind-another-kind-cluster coredns-66bff467f8-7z842"
"kind-another-kind-cluster etcd-another-kind-cluster-control-plane"
"kind-another-kind-cluster kindnet-k4vnm"
"kind-another-kind-cluster kube-apiserver-another-kind-cluster-control-plane"
"kind-another-kind-cluster kube-controller-manager-another-kind-cluster-control-plane"
"kind-another-kind-cluster kube-proxy-dllm6"
"kind-another-kind-cluster kube-scheduler-another-kind-cluster-control-plane"
"kind-kind coredns-66bff467f8-4lnsg"
"kind-kind coredns-66bff467f8-czsf6"
"kind-kind etcd-kind-control-plane"
"kind-kind kindnet-j682f"
"kind-kind kube-apiserver-kind-control-plane"
"kind-kind kube-controller-manager-kind-control-plane"
"kind-kind kube-proxy-trbmh"
"kind-kind kube-scheduler-kind-control-plane"
```

Check out the [github repo for a speed comparison](https://github.com/jonnylangefeld/kubectl-mc/tree/v1.0.1#speed-comparison).
If you have any questions or feedback email me [jonny.langefeld@gmail.com](mailto:jonny.langefeld@gmail.com) or tweet me
[@jonnylangefeld](https://twitter.com/jonnylangefeld).

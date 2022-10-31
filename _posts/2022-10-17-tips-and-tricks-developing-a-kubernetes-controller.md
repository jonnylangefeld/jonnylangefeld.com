---
layout: post
title:  "Tips and Tricks Developing a Kubernetes Controller"
categories: []
tags:
- kubernetes
- cncf
- clusters
- infrastructure
- automation
- api
- controllers
- operators
- tips & tricks
status: publish
type: post
published: true
meta: {}
---

This is a cross-post from the [original post on LinkedIn](https://www.linkedin.com/pulse/tips-tricks-developing-kubernetes-controller-jonny-langefeld).

In an effort to contribute to the Kubernetes controller development community, we want to line out a few of the highlights that truly helped us to implement a production grade controller that is reliable. These are generic so they apply to any Kubernetes controller and not just to infrastructure related ones.

### API Integration Tests via gomock

While [Kubebuilder already creates an awesome testing framework](https://book.kubebuilder.io/cronjob-tutorial/writing-tests.html) with Ginkgo and Envtest, which spins up a local Kubernetes API server for true integration tests, it is not complete if your controller has one or more integrations with third party APIs like in our case Vault, Buildkite and others. If your reconciliation logic contains an API call to a third party, it should be mocked during integration testing to not create a dependency or load on that API during your CI runs.

We chose [gomock](https://github.com/golang/mock) as our mocking framework and defined all API clients as interfaces. That allows us to implement the API clients as a gomock stub during the integration tests and as the actual API client during the build. The following is an example of one of such interfaces including the go:generate instructions to create the mock:

```go
//go:generate $GOPATH/bin/mockgen -destination=./mocks/buildkite.go -package=mocks -build_flags=--mod=mod github.com/cruise/cluster-operator/controllers/cluster BuildkiteClientInterface
type BuildkiteClientInterface interface {
 Create(org string, pipeline string, b *buildkite.CreateBuild) (*buildkite.Build, *buildkite.Response, error)
}
```

During integration tests we just replace the `Create` function with a stub that returns a `*buildkite.Build` or an `error`.

### Communication Between Sub-Controllers

It is often required that one controller needs to pass on information to another controller. For instance our netbox controller that provisions and documents CIDR ranges for new clusters as described in our last blog post needs to pass on the new CIDR ranges to the `ComputeSubnetwork` [as properties](https://github.com/GoogleCloudPlatform/k8s-config-connector/blob/3d23e31c10e5da222b6514140747674d2df29f98/crds/compute_v1beta1_computesubnetwork.yaml#L80), which is reconciled by the GCP Config Connector. We utilize the `Cluster` resource’s status property to pass along properties between sub-resources. That has the positive side effect that the `Cluster` resource contains all potentially generated metadata of the cluster in the status field. The root controller which reconciles the `Cluster` resource implements the logic and coordinates which source property goes to which target.

### Server-Side Apply

[Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/) is a Kubernetes feature that became GA in Kubernetes version 1.18 and stable in 1.22. It helps users and controllers to manage their resources through declarative configurations and define ownership of fields. It introduces the `managedField` property in the metadata of each resource storing which controller claims ownership over which field. That is important because otherwise two or more controllers can edit the same field, changing it back and forth, triggering reconciliation of each other and thus creating infinite loops. When we made the switch to Server-Side Apply, we decided to store each resource as go template yaml file, embed it via go 1.16’s `//go:embed` and apply it as [`*unstructured.Unstructured`](https://pkg.go.dev/k8s.io/apimachinery/pkg/apis/meta/v1/unstructured#Unstructured) resource. That is even though we have the go struct for the specific resource available. The issue with using the go struct is that empty fields (nil values) count as fields with an opinion by that controller. Imagine an int field on the struct. As soon as a struct is initialized, that int field is set to 0. The json marshaller now doesn’t know if it was explicitly set to 0 or if it is just nil and marshalls it as 0 into the resulting json which gets sent to the API server. With an `*unstructured.Unstructured` resource we ensure that we only apply fields that the controller has an opinion about. It works very much like a regular `kubectl apply` at this point. A go template yaml file could look like the following:

{% raw %}
```yaml
apiVersion: iam.cnrm.cloud.google.com/v1beta
kind: IAMServiceAccount
metadata:
  annotations:
    cnrm.cloud.google.com/project-id: {{ .Spec.Project }}
  name: {{ . | serviceAccountName }}
  namespace: {{ .Namespace }}
spec:
  description: "default service account for cluster {{ .Name }}"
  displayName: {{ . | serviceAccountName }}
```
{% endraw %}

The template properties get filled through parsing the file using a `*Template` from the [`text/template`](https://pkg.go.dev/text/template) package. The templated yaml file gets parsed into the `*unstructured.Unstructured` resource and applied via the [CreateOrPatch function in controller-runtime](https://github.com/kubernetes-sigs/controller-runtime/blob/f236f0345ad2933912ebf34bfcf0f93620769654/pkg/controller/controllerutil/controllerutil.go#L232). This allowed us to only explicitly set fields we have an opinion about.

This was especially important in conjunction with the GCP Config Connector as it often writes resulting values (e.g. a default cluster version) back to the original spec of the resource. Thus our controller and the GCP Config Connector controller often would “fight” over a field before we rolled out Server-Side Apply, changing it back and forth. With Server-Side Apply a field is clearly claimed by one controller, while the other controller accepts the opinion of the first controller, thus eliminating infinite control loops.

If you implement or build upon any of these frameworks, I'd love to hear about it — reach out to me on [Twitter](https://twitter.com/jonnylangefeld) with your feedback!

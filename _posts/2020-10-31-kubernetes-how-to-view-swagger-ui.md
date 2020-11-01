---
layout: post
title:  "Kubernetes: How to View Swagger UI"
categories: []
tags:
- kubernetes
- swagger
- api
- tips & tricks
status: publish
type: post
published: true
meta: {}
---
Often times, especially during development of software that talks to the kubernetes API server, I actually find myself looking for a detailed kubernetes API specification. And no, I am not talking about the [official kubernetes API reference](https://kubernetes.io/docs/reference/) which mainly reveals core object models. I am also interested in the specific API paths, the possible headers, query parameters and responses.

Typically you find all this information in an [openapi](https://swagger.io/specification/) specification doc which you can view via the [Swagger UI](https://swagger.io/tools/swagger-ui/), [ReDoc](https://github.com/Redocly/redoc) or other tools of that kind.

So the next logical step is to google for something like 'kubernetes swagger' or 'kubernetes openapi spec' and you'd hope for a Swagger UI to pop up and answer all your questions. But while some of those search results can lead you in the right direction, you won't be pleased with the Swagger UI you were looking for.

The reason for that is the spec for every kubernetes API server is actually different due to [custom resource definitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/) and therefore exposes different paths and models.

And that requires the kubernetes API server to actually generate it's very own openapi specification, which we will do in the following:

<!--more-->

First make sure that you are connected to your kubernetes API server as your current kube context. You can double check via `kubectl config current-context`. You then want to open [a reverse proxy](https://kubernetes.io/docs/tasks/access-application-cluster/access-cluster/#using-kubectl-proxy) to your kubernetes API server:

```bash
kubectl proxy --port=8080
```

That saves us a bunch of authentication configuration that's now all handled by `kubectl`. Run the following commands in a new terminal window to keep the reverse proxy alive (or run the reverse proxy in the background). Save the Swagger file for your kubernetes API server via the following command:

```bash
curl localhost:8080/openapi/v2 > k8s-swagger.json
```

As last step we now just need to start a Swagger ui server with the generated Swagger json as input. We will use a docker container for that:

```bash
docker run \
    --rm \
    -p 80:8080 \
    -e SWAGGER_JSON=/k8s-swagger.json \
    -v $(pwd)/k8s-swagger.json:/k8s-swagger.json \
    swaggerapi/swagger-ui
```

Now visit [http://localhost](http://localhost) and you'll get a Swagger UI including the models and paths of all custom resources installed on your cluster!

<img src="/assets/posts/swagger-ui-argo.png" width="100%" align="middle" style="margin: 15px" />

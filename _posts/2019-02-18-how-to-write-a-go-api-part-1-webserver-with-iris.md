---
layout: post
title:  "How to write a Go API Part 1: A Webserver With Iris"
categories: []
tags:
- go
- golang
- api
- programming
- software development
- repo
- go base project
- iris
status: publish
type: post
published: true
meta: {}
---
Today we are going to look at my favorite setup for an API built with Go. We will build a simple application that includes all the basics to build a powerful, scalable web app. Keep on reading if you are interested in how to get your first Go API kicked off. As of today the main packages used include [Iris](https://github.com/kataras/iris), [GORM](https://github.com/jinzhu/gorm) and [Dockertest](https://github.com/ory/dockertest). I will be guiding you through a follow-along tutorial in three parts, one for each of the main packages.

For those who are just interested in the finalized code, the complete repository with all files can be found [here](https://github.com/jonnylangefeld/go-api-base-project).
This tutorial assumes Mac OS as the operating system, but of course everything works on other systems too (It is just some extra work to lookup the respective commands 😉).

### Where to Start

If you haven't yet, [install Go](https://golang.org/doc/install#testing). For Mac OS it is the easiest to use [brew](https://brew.sh/) with the command `brew install go`. Then, we initialize our project. With Go version 1.11, modules were introduced, which means from now on you don't have to develop all you projects in `GOPATH` anymore. You create your working directory wherever you want. Start by typing

* `mkdir my-go-api-project` to create the directory
* `cd my-go-api-project` to change into it
* `go mod init my-go-api` to initialize our project

With these commands, you just initialized your Go module. In your directory, you will now find a `go.mod` file. So far it's pretty empty and only contains the package name you gave it, but it's gonna fill up later with all the dependencies we will be using.  
Next, we will create a `main.go` file, as every Go program needs one. You can do so by typing

```bash
echo "package main" >> main.go
```

into your command line. Let's first write a quick hello world program to see if everything works with your Go installation. You can open the current directory with the editor of your choice. I will just be posting the necessary code in here. Fill your `main.go` package with the following code (we already created the first line through the command above, I just included it here for completeness):

```go
package main

import (
    "fmt"
)

func main() {
    fmt.Printf("Hello World")
}
```
<!--more-->
Now run `go build` in your terminal in the current working directory. A new file with the package name you gave in the `go mod init` command earlier has been created. Run the file with `./my-go-api`. If you see the output `Hello World`, everything is working as expected.

### Getting Started With Iris

[Iris](https://github.com/kataras/iris) is one of the more popular, fast, and easy-to-use web frameworks for Go. Of course [any other](https://github.com/mingrammer/go-web-framework-stars) could be used, but I decided to use Iris for now, even though there are some critiques [out there](https://www.reddit.com/r/golang/comments/57w79c/why_you_really_should_stop_using_iris/).  
Let's change our simple hello world program from above, so that an actual web server is started that sends a `Hello World` response. Replace the contents in the `main.go` file with the following code:

```go
package main

import (
    "github.com/kataras/iris"
)

func main() {
    // Run the function to create the new Iris App
    app := newApp()

    // Start the web server on port 8080
    app.Run(iris.Addr(":8080"), iris.WithoutServerError(iris.ErrServerClosed))
}

func newApp() *iris.Application {
    // Initialize a new Iris App
    app := iris.New()

    // Register the request handler for the endpoint "/"
    app.Get("/", func(ctx iris.Context) {
        // Return something by adding it to the context
        ctx.Text("Hello World")
    })

    return app
}
```

The comments should explain what we did there. Note that I now import `github.com/kataras/iris`. Try to run 

```bash
go build
```

now. Your binary `my-go-api` will be updated, but more importantly the command just downloaded all the packages needed from github.com. Check out your `go.mod` file now, you will see it now contains all the dependencies of Iris. Run the app again with

```bash
./my-go-api
```

and access [locahlost:8080](http://localhost:8080) in your browser now. Congrats 🎉! You just started your own API.

### Variable Endpoints

Now, let's create one new endpoint with a variable path. Just add another `app.Get` reference right next to the existing one:

```go
// Register an endpoint with a variable
app.Get("{name:string}", func(ctx iris.Context) {
    ctx.Text(fmt.Sprintf("Hello %s", ctx.Params().Get("name")))
})
```

The `ctx.Params().Get("name")` part accesses the variable from the context. Don't forget to import the package `fmt` now, since we need it to generate the string with a variable:

```go
import (
    "fmt"
    "github.com/kataras/iris"
)
```

`go build` and run your application again with `./my-go-api`. Check out [locahlost:8080/Bill](http://localhost:8080/Bill) in your browser.

You did it 🎊! From here you can now expand and scale your API. You can download the complete source code for this blog post [here](https://github.com/jonnylangefeld/go-api-base-project/archive/part-1.zip).

Make sure to [continue reading part two on how to integrate a database](/blog/how-to-write-a-go-api-part-2-database-integration).

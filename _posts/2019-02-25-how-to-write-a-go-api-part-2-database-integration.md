---
layout: post
title:  "How to write a Go API Part 2: Database Integration With GORM"
categories: []
tags:
- go
- golang
- api
- programming
- software development
- repo
- go base project
- gorm
status: publish
type: post
published: true
meta: {}
---
This is part 2 of 3 blog posts on how to write a Go API. Start with the [first part](/blog/how-to-write-a-go-api-part-1-webserver-with-iris) to build upon the repository. If you are only interested in the database integration, make sure to [download the source code of the first part](https://github.com/jonnylangefeld/go-api-base-project/archive/part-1.zip), as we are incrementally building upon it.

Most APIs are going to use some kind of database integration. Instead of just using raw SQL to avoid SQL injection and also to abstract the kind of database in the background, there are good reasons to use an [ORM or Object-relational mapping](https://en.wikipedia.org/wiki/Object-relational_mapping) (okay, there are also reasons [against it](https://medium.com/@mithunsasidharan/should-i-or-should-i-not-use-orm-4c3742a639ce)). It basically means that you implement the database model entirely in the programming language and let the ORM tool do all the SQL generation and model mapping.

For this example, we are going to connect our API to a [PostgreSQL](https://www.postgresql.org/) database. For local development, it's going to be the easiest to just spin up your own development database [via Docker](https://youtu.be/JprTjTViaEA) with

```bash
docker run -d \
    --name my-postgis-database \
    -e POSTGRES_PASSWORD=mysecretpassword \
    -p 5432:5432 
    mdillon/postgis
```

The database is now already running in the background as a Docker container on your computer. We will get back to it later. We will be using [GORM](https://github.com/jinzhu/gorm) as the Go ORM implementation of choice.

First, we will need a model definition. For this tutorial, we will just use a simple object for some orders in an online store. Each order will have an ID, a description and a timestamp. To define the object, make a new sub directory in the project directory with `mkdir model` and create a new file called `model.go` inside of it (for instance with `touch model/model.go`). Add the following code into the `model.go` file:

```go
package model

// Order is the database representation of an order
type Order struct {
    ID          int64  `gorm:"type:int" json:"id"`
    Description string `gorm:"type:varchar" json:"description"`
    Ts          int64  `gorm:"timestamp" json:"ts"`
}
```

As you can see, this is a Go object (`struct`) with all the attributes we need for our order. You could also say this Go object is a representation for a table in our database later. <!--more-->

Now let's go back into our `main.go` file and let's add `"github.com/jinzhu/gorm"` and the dialect `_ "github.com/jinzhu/gorm/dialects/postgres"` (Don't forget the underscore as the dialect is not directly used in our main function) as well as our own model definition `"go-api-base-project/model"` to our imports :

```go
import (
    "fmt"
    "github.com/jinzhu/gorm"
    _ "github.com/jinzhu/gorm/dialects/postgres"
    "go-api-base-project/model"
    "github.com/kataras/iris/v12"
)
```

These imports are needed for the next code block, which we will insert right at the beginning of the `main()` function, even before we call the `newApp()` function:

```go
// Create the databse connection
db, err := gorm.Open(
    "postgres",
    "host=localhost port=5432 user=postgres dbname=postgres password=mysecretpassword sslmode=disable",
    )
// End the program with an error if it could not connect to the database
if err != nil {
    panic("could not connect to database")
}

// Create the default database schema and a table for the orders
db.AutoMigrate(&model.Order{})

// Closes the database connection when the program ends
defer func() {
    _ = db.Close()
}()
```

In addition to that we will register another endpoint in the `newApp()` function, just like we have done before. We need to instantiate a variable for the result, which is a slice of the `model` we defined earlier. The endpoint `/orders` will perform a database request via `db.Find(&orders)` and return it via `ctx.JSON(orders)`. Add the following code at the end of the `newApp()` function (but above the `return app` statement):

```go
// Define the slice for the result
var orders []model.Order

// Endpoint to perform the database request
app.Get("/orders", func(ctx iris.Context) {
    db.Find(&orders)
    // Return the result as JSON
    ctx.JSON(orders)
})
```

It appears that the new endpoint is making use of the `db` object we created in the `main()` function. In order for it to be used in the `newApp()` function, we need to pass it down. Therefore add the payload `db *gorm.DB` to the `newApp()` function like this:

```go
func newApp(db *gorm.DB) *iris.Application {

}
```

and pass the `db` object down when the `newApp()` function is called in the `main()` function:

```go
app := newApp(db)
```

The updated `main.go` file will now look something like this:

```go
package main

import (
    "fmt"
    "my-go-api/model"

    "github.com/jinzhu/gorm"
    _ "github.com/jinzhu/gorm/dialects/postgres"
    "github.com/kataras/iris/v12"
)

func main() {

    // Create the databse connection
    db, err := gorm.Open(
        "postgres",
        "host=localhost port=5432 user=postgres dbname=postgres password=mysecretpassword sslmode=disable",
    )
    // End the program with an error if it could not connect to the database
    if err != nil {
        panic("could not connect to database")
    }

    // Create the default database schema and a table for the orders
    db.AutoMigrate(&model.Order{})

    // Closes the database connection when the program ends
    defer func() {
        _ = db.Close()
    }()

    // Run the function to create the new Iris App
    app := newApp(db)

    // Start the web server on port 8080
    app.Run(iris.Addr(":8080"), iris.WithoutServerError(iris.ErrServerClosed))
}

func newApp(db *gorm.DB) *iris.Application {
    // Initialize a new Iris App
    app := iris.New()

    // Register the request handler for the endpoint "/"
    app.Get("/", func(ctx iris.Context) {
        // Return something by adding it to the context
        ctx.Text("Hello World")
    })

    // Register an endpoint with a variable
    app.Get("{name:string}", func(ctx iris.Context) {
        _, _ = ctx.Text(fmt.Sprintf("Hello %s", ctx.Params().Get("name")))
    })

    // Define the slice for the result
    var orders []model.Order

    // Endpoint to perform the database request
    app.Get("/orders", func(ctx iris.Context) {
        db.Find(&orders)
        _, _ = ctx.JSON(orders)
    })

    return app
}
```

As always at this point you can build and run your application again (`go build && ./my-go-api`).  
To see that everything went well, you can install `psql` via **`brew install postgres`** and use it in your command line to see if the database table was created correctly:

```bash
echo "SELECT * FROM orders" | \
psql "host=localhost port=5432 user=postgres dbname=postgres password=mysecretpassword sslmode=disable"
```

The result should look like this:

```bash
 id | description | ts
----+-------------+----
(0 rows)
```

This table was entirely created by your Go application. Let's add some life to it. Execute this in your command line:

```bash
echo "INSERT INTO orders VALUES (1, 'An old glove', 1550372443000);\
      INSERT INTO orders VALUES (2, 'Something you don''t need', 1550372444000);" | \
psql "host=localhost port=5432 user=postgres dbname=postgres password=mysecretpassword sslmode=disable"
```

If you execute the `SELECT` command from above again, you will now find the two database entries:

```
 id |       description        |      ts
----+--------------------------+---------------
  1 | An old glove             | 1550372444000
  2 | Something you don't need | 1550372444000
(2 rows)
```

But the most fun part is, if you now enter [locahlost:8080/orders](http://localhost:8080/orders) in your browser, you will get a JSON response of the orders we just inserted:

```json
[
    {
        "id": 1,
        "description": "An old glove",
        "ts": 1550372443000
    },
    {
        "id": 2,
        "description": "Something you don't need",
        "ts": 1550372444000
    }
]
```

Tadaaa 🎉 we integrated the database. You can download the complete source code for this blog post from [here](https://github.com/jonnylangefeld/go-api-base-project/archive/part-2.zip).

Make sure to [continue reading the third part on how to test your API](/blog/how-to-write-a-go-api-part-3-testing-with-dockertest).

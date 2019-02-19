---
layout: post
title:  "How to write a Go API Part 3: Testing With Dockertest"
categories: []
tags:
- go
- golang
- api
- programming
- software development
- repo
- go base project
- dockertest
status: publish
type: post
published: true
meta: {}
---
This is part 3 of 3 blog posts on how to write a Go API. Read the [first](/blog/how-to-write-a-go-api-part-1-webserver-with-iris) and [second](/blog/how-to-write-a-go-api-part-2-database-integration) part first to build upon the repository. If you are only interested in testing your API, make sure to [download the source code of the second part](https://github.com/jonnylangefeld/go-api-base-project/archive/part-2.zip), as we are incrementally building upon it.

This part is all about testing our Go API. The challenge here is to mock the webserver and the database. Iris comes with it's own testing package. To test the database, I have found that [Dockertest](https://github.com/ory/dockertest) is a pretty good choice, as it is the only possibility to mock the actual setup of the database inside a Docker container. The module spins up a defined Docker container, runs the tests and destroys it again as if nothing happened. So make sure you have [Docker installed](https://youtu.be/JprTjTViaEA) and the daemon up and running as you are executing the tests.

Let's get started with the code by creating a new file:

```bash
echo "package main" >> main_test.go
```

For typical Go tests, this would be the file that contains all the unit tests. These are basically functions starting with the word `Test...`. And we will get to them later, but in our case we have some preliminary steps that are needed for all our unit tests later. And that is setting up the database and starting up the Iris application. That's what we will do first.  
Add the following code into the `main_test.go` file:

```go
var db *gorm.DB
var app *iris.Application

func TestMain(m *testing.M) {

}
```

The two variables `db` and `app` are both empty [pointers](https://tour.golang.org/moretypes/1) to a `*gorm.DB` and a `*iris.Application`, which we will fill with life later. The `TestMain(m *testing.M)` function is automatically executed by Go before the tests run. So this is where we set up the app and the database. Let's start with the database, since the app needs the database, as described in [part two](/blog/how-to-write-a-go-api-part-2-database-integration). In the following, we will successively add little code blocks into the `TestMain()` function and I will show the entire code in the end.  
First, we need to create a pool in which we can run the Docker container later:

```go
// Create a new pool for Docker containers
pool, err := dockertest.NewPool("")
if err != nil {
    log.Fatalf("Could not connect to Docker: %s", err)
}
```

In order to run the pool, we need to define an options object with all the parameters for the Docker container we want to run. We basically spin up the same Docker container as in [part two](/blog/how-to-write-a-go-api-part-2-database-integration), but this time with Go code. I also changed the port, just in case you still have the Postgres Docker container running from [part two](/blog/how-to-write-a-go-api-part-2-database-integration):

```go
// Pull an image, create a container based on it and set all necessary parameters
opts := dockertest.RunOptions{
    Repository:   "mdillon/postgis",
    Tag:          "latest",
    Env:          []string{"POSTGRES_PASSWORD=mysecretpassword"},
    ExposedPorts: []string{"5432"},
    PortBindings: map[docker.Port][]docker.PortBinding{
        "5432": {
            {HostIP: "0.0.0.0", HostPort: "5433"},
        },
    },
}

// Run the Docker container
resource, err := pool.RunWithOptions(&opts)
if err != nil {
    log.Fatalf("Could not start resource: %s", err)
}
```

Next, we will try and connect to the database just as the actual code in the `main.go` file would try and connect to the database. <!--more--> The Docker container is going to take a while to download and spin up. Since we don't know how long we need to wait for that, the `github.com/ory/dockertest` package has a build-in `Retry()` function, that tries to connect to the database in a loop with exponentially growing time intervals in between. Add this code underneath the last:

```go
// Exponential retry to connect to database while it is booting
if err := pool.Retry(func() error {
    databaseConnStr := fmt.Sprintf("host=localhost port=5433 user=postgres dbname=postgres password=mysecretpassword sslmode=disable")
    db, err = gorm.Open("postgres", databaseConnStr)
    if err != nil {
        log.Println("Database not ready yet (it is booting up, wait for a few tries)...")
        return err
    }

    // Tests if database is reachable
    return db.DB().Ping()
}); err != nil {
    log.Fatalf("Could not connect to Docker: %s", err)
}
```

Note how we fill the `db` object defined earlier here. So as soon as we successfully leave the `Retry()` function, we have our database ready and can now populate it with the test data. To structure code a little better, I usually do that in a separate function (in this same file). So just add the following function and variable for samples right next to the `TestMain()` function:

```go
func initTestDatabase() {
    db.AutoMigrate(&model.Order{})

    db.Save(&sampleOrders[0])
    db.Save(&sampleOrders[1])
}

var sampleOrders = []model.Order{
    {
        ID:          1,
        Description: "An old glove",
        Ts:          time.Now().Unix() * 1000,
    },
    {
        ID:          2,
        Description: "Something you don't need",
        Ts:          time.Now().Unix() * 1000,
    },
}
```

Back inside the `TestMain()` function, we can then call the `initTestDatabase()` function, as well as create the mock Iris app for the tests:

```go
log.Println("Initialize test database...")
initTestDatabase()

log.Println("Create new Iris app...")
app = newApp(db)
```

Now, right after we have the `app` and the `db` ready, we can finally run our actual test cases, which we will define later. At this point we will just call

```go
// Run the actual test cases (functions that start with Test...)
code := m.Run()
```

Once the test cases have run, we will just remove the Docker container and exit the program:

```go
// Delete the Docker container
if err := pool.Purge(resource); err != nil {
    log.Fatalf("Could not purge resource: %s", err)
}

os.Exit(code)
```

At this point we can now add our actual test cases (functions that start with `Test...`). To compare the actual result with an expected result, we use the package [`github.com/stretchr/testify`](https://github.com/stretchr/testify). I have annotated the following code to understand what we are doing:

```go
func TestName(t *testing.T) {
    // Request an endpoint of the app
    e := httptest.New(t, app, httptest.URL("http://localhost"))
    t1 := e.GET("/Bill").Expect().Status(iris.StatusOK)

    // Compare the actual result with an expected result
    assert.Equal(t, "Hello Bill", t1.Body().Raw())
}

func TestOrders(t *testing.T) {
    e := httptest.New(t, app, httptest.URL("http://localhost"))
    t1 := e.GET("/orders").Expect().Status(iris.StatusOK)
    
    expected, _ := json.Marshal(sampleOrders)
    assert.Equal(t, string(expected), t1.Body().Raw())
}
```

Now, I don't assume that any of you have kept track of all the necessary imports we  need for all the code above. So here is the import block that we need in the beginning of the `test_main.go` file:

```go
import (
    "encoding/json"
    "fmt"
    "log"
    "my-go-api/model"
    "os"
    "testing"
    "time"

    "github.com/jinzhu/gorm"
    "github.com/kataras/iris"
    "github.com/kataras/iris/httptest"
    "github.com/ory/dockertest"
    "github.com/ory/dockertest/docker"
    "github.com/stretchr/testify/assert"
)
```

And that's it 🎉! We can now run the tests with 

```bash
go test -v
```

And we will get the following output:

```
2019/02/17 08:15:06 Database not ready yet (it is booting up, wait for a few tries)...
2019/02/17 08:15:12 Initialize test database...
2019/02/17 08:15:12 Create new Iris app...
=== RUN   TestName
--- PASS: TestName (0.00s)
=== RUN   TestOrders
--- PASS: TestOrders (0.00s)
PASS
ok      my-go-api       17.111s
```

Yay! The tests are successful 👍🏼  
If you missed something, [click here](https://github.com/jonnylangefeld/go-api-base-project/blob/part-3/main_test.go) to see the code of the entire `test_main.go` file, or just [download the entire source code of the project](https://github.com/jonnylangefeld/go-api-base-project/archive/part-3.zip).
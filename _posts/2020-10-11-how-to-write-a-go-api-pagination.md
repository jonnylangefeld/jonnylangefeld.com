---
layout: post
title:  "How to write a Go API: Pagination"
categories: []
tags:
- go
- golang
- api
- programming
- software development
- repo
- ultimate guide
- pagination
status: publish
type: post
published: true
meta: {}
---
*This plog post is part of a [series of blog posts](/blog/how-to-write-a-go-api-the-ultimate-guide) on how to write a go API with all best practices. If you're here just for pagination, keep on reading. If you want all the context including project setup and scaffolding, read the **[Ultimate Guide](/blog/how-to-write-a-go-api-the-ultimate-guide)***.

Pagination is important for any possible list response of arrays with undefined length. That is so we control the throughput and load on our API. We don't want to query the database for 10 Million items at once and send them all through the http server. But rather we send a finite subset slice of the array of undefined length.  

The general concept will be an API object with an `Items` slice and a `NextPageID`:

```go
// ArticleList contains a list of articles
type ArticleList struct {
	// A list of articles
	Items []*Article `json:"items"`
	// The id to query the next page
	NextPageID int `json:"next_page_id,omitempty" example:"10"`
} // @name ArticleList
```
<sup>(*[source](https://github.com/jonnylangefeld/go-api/blob/v1.0.0/pkg/types/types.go#L30-L36)*)</sup>

To retrieve the next page ID via the URL, we'll use a [custom middleware](/blog/how-to-write-a-go-api-the-ultimate-guide#8-custom-middlewares):

```go
r.With(m.Pagination).Get("/", ListArticles)
```
<sup>(*[source](https://github.com/jonnylangefeld/go-api/blob/v1.0.0/pkg/api/api.go#L50)*)</sup>

The `With()` call injects a middleware for just the current sub-tree of the router and can be used for every list response. Let's have a closer look into the `Pagination` middleware:

<!--more-->

```go
// Pagination middleware is used to extract the next page id from the url query
func Pagination(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		PageID := r.URL.Query().Get(string(PageIDKey))
		intPageID := 0
		var err error
		if PageID != "" {
			intPageID, err = strconv.Atoi(PageID)
			if err != nil {
				_ = render.Render(w, r, types.ErrInvalidRequest(fmt.Errorf("couldn't read %s: %w", PageIDKey, err)))
				return
			}
		}
		ctx := context.WithValue(r.Context(), PageIDKey, intPageID)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
```
<sup>(*[source](https://github.com/jonnylangefeld/go-api/blob/v1.0.0/pkg/middelware/pagination.go#L19-L35)*)</sup>

The middleware takes care of some common operations every paginated response has to do. It extracts the `next_page` query parameter, transforms it into an integer (this might not be necessary depending ont he type of key in your database) and injects it into the context.  
Once the `/articles?page_id=1` endpoint is hit, we just get the page id from the context and call the database from within the http handler:

```go
func ListArticles(w http.ResponseWriter, r *http.Request) {
	pageID := r.Context().Value(m.PageIDKey)
	if err := render.Render(w, r, DBClient.GetArticles(pageID.(int))); err != nil {
		_ = render.Render(w, r, types.ErrRender(err))
		return
	}
}
```
<sup>(*[source](https://github.com/jonnylangefeld/go-api/blob/v1.0.0/pkg/api/operations.go)*)</sup>

I like the database logic for pagination the most: We basically get all items of a table, ordered by their primary key, that are greater than the queried ID and limit it to one larger than the page size. That is so we can return a slice with the defined page size as length and use the extra item to insert the `next_page_id` into the API response. For example if we assume a page size of 10 and have 22 items in a database table with IDs 1-22 and we receive a query with a page id of 10, then we query the database for items 10-20 (including, that means it's 11 distinct items), package items 10-19 up into the API response and use the 11th item to add the `"next_page_id": 20` to the API response. This logic looks as follows:

```go
// GetArticles returns all articles from the database
func (c *Client) GetArticles(pageID int) *types.ArticleList {
	articles := &types.ArticleList{}
	c.Client.Where("id >= ?", pageID).Order("id").Limit(pageSize + 1).Find(&articles.Items)
	if len(articles.Items) == pageSize+1 {
		articles.NextPageID = articles.Items[len(articles.Items)-1].ID
		articles.Items = articles.Items[:pageSize] // this shortens the slice by 1
	}
	return articles
}
```
<sup>(*[source](https://github.com/jonnylangefeld/go-api/blob/v1.0.0/pkg/db/db.go#L81-L90)*)</sup>

For this to work as efficient as intended, it's important that the database table's primary key is the `id` column we are ordering by in the example above. With that the described database query is fairly efficient, as the IDs are already stored in order in a tree and the database doesn't have to start ordering once the request is received. All the database has to do is find the queried ID (which the database can do via binary search in `O(log n)`) and then return the next `pageSize` items.

The API response will look something like this (shortened):

```json
{
    "items":[
        {"id":1,"name":"Jelly Beans","price":2.99}
        {"id":2,"name":"Skittles","price":3.99}
    ],
    "next_page_id": 3
}
```
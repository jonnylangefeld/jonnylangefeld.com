---
layout: post
title:  "How to add a Read More Button to Your Jekyll Blog That Doesn't Suck"
categories: []
tags:
- blog
- tutorial
- jekyll
- how-to
status: publish
type: post
published: true
meta: {}
---
[Jekyll](https://jekyllrb.com/) is a great piece of software. It has simple, yet powerful features to cheaply run a personal website, including a blog. However, once I had the idea to add the functionality of a 'read more...' button, I couldn't find a satisfying tutorial that would explain how to properly add such a feature. The problem was, that all the tutorials I found had in common that the 'read more...' button is just an [anchor tag](https://www.google.com/search?q=what+is+an+anchor+tag) to the location in the text where the button was placed. My issue with that was, that the reader always had to wait for a page to load. And even after that the height on the screen of where they left off is most likely not the same as after the reload, so that they end up searching for where they left off before the reload.  
My goal was that the hidden part of the blog post instantaneously shows up without moving the text around on the screen. Continue reading to find out how I did it.

<!--more-->

##### Step 1: Add `<!--more-->` tag to posts

The `<!--more-->` in a post is an html comment and won't show up on your final page, but it will help our `.html` file to hide the part of your blog post that should only show up once the button is clicked. Place it anywhere in your post to hide the part below it.

##### Step 2: Split the post in the `.html` file

Chances are, that in the `.html` file that you use to render your blog, you have a loop iterating over your posts looking something like this:

{% raw %}
```html
<div class="blog">
  {% for page in paginator.posts %}
    <article class="post" itemscope itemtype="http://schema.org/BlogPosting">
        {{ page.content }}
    </article>
  {% endfor %}
</div>
```
{% endraw %}

All we need to do is check for the `<!--more-->` tag and put the second half into it's own `<div>`. The button itself is actually a `checkbox` that we will style later to make it look nice. But this `checkbox` will help us with the toggle feature. So let's go ahead and replace the {% raw %}`{{ page.content }}`{% endraw %} part with the following:

{% raw %}
```html
{% if page.content contains '<!--more-->' %}
    <div>
        {{ page.content | split:'<!--more-->' | first }}
    </div>
    <input type="checkbox" class="read-more-state" id="{{ page.url }}"/>
    <div class="read-more">
        {{ page.content | split:'<!--more-->' | last }}
    </div>
    <label for="{{ page.url }}" class="read-more-trigger"></label>
{% else %}
    {{ page.content }}
{% endif %}
```
{% endraw %}

##### Step 3: Let's add some style

Just add the following to your `css` and play around with it until you like it:

```css
.read-more {
    opacity: 0;
    max-height: 0;
    font-size: 0;
    transition: .25s ease;
    display: none;
}

.read-more-state {
  display: none;
}

.read-more-state:checked ~ .read-more {
  opacity: 1;
  font-size: inherit;
  max-height: 999em;
  display: inherit;
}

.read-more-state ~ .read-more-trigger:before {
  content: 'Continue reading...';
}

.read-more-state:checked ~ .read-more-trigger:before {
  content: 'Show less...';
}

.read-more-trigger {
  cursor: pointer;
  padding: 1em .5em;
  color: #0085bd;
  font-size: .9em;
  line-height: 2;
  border: 1px solid #0085bd;
  border-radius: .25em;
  font-weight: 500;
  display: grid;
  text-align: center;
}
```

And voilà!!! We have a really nice 'Continue reading...' button that changes into a 'Show less...' as soon as it's expanded. You can try it out on most of my posts on my [homepage](https://jonnylangefeld.com). If you have any question or feedback, feel free to drop my a line on any of my social media. Thanks for reading!
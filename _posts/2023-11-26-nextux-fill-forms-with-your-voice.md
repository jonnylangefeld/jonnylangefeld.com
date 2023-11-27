---
layout: post
title: "nextux.ai - Fill Forms with Your Voice"
categories: []
tags:
  - project
  - typescript
  - tailwind
  - daisyui
  - nextjs
  - react
  - openai
  - ai
status: publish
type: post
published: true
meta: {}
---

I recently launched a new side project called [nextux.ai](https://nextux.ai). It's a simple web app that allows you to fill entire forms with your voice. It's
powered by [OpenAI](https://openai.com) and [Next.js](https://nextjs.org/). Check out the demo video below:

<iframe width="100%" height="405" src="https://www.youtube.com/embed/03J4aSGsOaY?si=H4PQX7EezCUmiKYO" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" allowfullscreen></iframe>

You can try it out yourself at [nextux.ai](https://nextux.ai).

Currently the project is just a versatile demo to show what's possible with [OpenAI's Whisper model](https://openai.com/research/whisper) and
[functions](https://platform.openai.com/docs/guides/function-calling). It shows that you can get any structured data out of an audio recording. I think this
could be useful to call centers or to simplify UIs like flight search engines or long website forms. It could also serve as accessibility feature for people who
find it easier to speak to a computer rather than type and use their mouse. If you have other ideas this technology could be used, let me know on
[X @jonnylangefeld](https://x.com/jonnylangefeld). Some future ideas involve streaming audio so that you see the form filling out in real-time as you speak.

In the following sections I will go into more detail into the technologies I chose for this project and why I chose them.

### [React](https://reactjs.org/) and [TypeScript](https://www.typescriptlang.org/)

These are some well-proven technologies that power most of the web today. I personally wanted to get more experience with TypeScript and React so this project
was a great excuse to do just that. I really like the capabilities that TypeScript adds to vanilla javascript and that any javascript code still works in
TypeScript. And React is obviously great to build dynamic web apps with live updates anywhere. For instance the ability to flip the form to a code editor and
live update the form was super easy to build in React.

<!--more-->

### [Next.js](https://nextjs.org/) and [Vercel](https://vercel.com/)

I chose Next.js because it's a great framework for building React apps. It's very easy to get started with and it comes with a lot of features out of the box.
It supports server-side rendering which makes it super fast. It also scales seamlessly from 1 user to 100s of 1000s of users. My favorite feature of vercel must
be the [preview deployments](https://vercel.com/docs/deployments/preview-deployments), which allows you to preview every commit/PR in a separate environment.
This is super useful for testing and reviewing changes before they go live.

### Styling with [Tailwind CSS](https://tailwindcss.com/) and [daisyUI](https://daisyui.com/)

I saw more and more projects that inspired me using Tailwind CSS so I wanted to see what the hype is all about. I really like the utility-first approach and the
fact that you can build a beautiful UI without writing a single line of CSS. I also like that Tailwind never gets into your way if a CSS feature is not
supported yet. For instance, for the 3D flip effect I needed a `perspective` CSS property which is not yet supported by Tailwind. But with the
`[perspective: 3000px]` class notation I could still use it.

I've seen many people mention the long list of classes as a downside of Tailwind. However, I think Tailwind is best used in combination with React, where
everything that's reusable should be a component anyway. And with that all the styling that's need for a certain component just lives right next to the actual
component. I find that easier compared to separate CSS files, where I first have to find which selectors apply.

I used [daisyUI](https://daisyui.com/) as a Tailwind plugin to get some nice looking components out of the box. I liked that daiyUI just adds more custom
classes to Tailwind and otherwise works exactly the same. For instance even the Tailwind code completion and class sorting in my IDE VS Code still works with
the additional daisyUI classes without any further configuration. And with that you get a consistent UI, where some
[smart open source community](https://github.com/saadeghi/daisyui) spent a lot of thought on the design.

### [OpenAI](https://openai.com/)

As a major player in the AI space, OpenAI is a great choice for any AI project. I really like their API design and how fair the pricing is. The
[Whisper model](https://openai.com/research/whisper) has an outstanding speech to text recognition. One major feature that [nextux.ai](https://nextux.ai) makes
use of is [function calling](https://platform.openai.com/docs/guides/function-calling). It guarantees a valid json response for a given
[json schema](https://json-schema.org/understanding-json-schema). This json schema is used to render the form using
[`react-jsonschema-form`](https://www.npmjs.com/package/react-jsonschema-form) and to define the output of the OpenAI API response, so it serves a double duty.
I'm really excited as to what OpenAI has up their sleeves next and am looking forward to trying it out.

### Feature Flags with [Hypertune](https://hypertune.dev/)

I realize that this project with a single developer probably doesn't present the most urgent necessity to integrate feature flags. However, one reason for this
project was for me to try out and integrate new technologies that I am excited about and Hypertune fell right in that niche. It was easy to
[get started](https://docs.hypertune.com/getting-started/set-up-hypertune) and everything is based off a [GraphQL](https://graphql.org/learn/schema/) schema.
The [`hypertune`](https://www.npmjs.com/package/hypertune) library translates that then into TypeScript types that can be used in your project. I for instance
used it to skip expensive API calls during development. Rather than calling the Whisper API every time I wanted to test something on the form, I just had a
feature flag to skip the API call and always respond with a hard coded transcript:

```typescript
if ((await flags()).skipExpensiveAPICalls().get(false)) {
  return "Hello, my name is Peter";
}
```

### Logging with [Betterstack](https://betterstack.com/)

For logging I chose Betterstack. I really liked how easy it was to integrate by just setting an environment variable and then wrapping the `next.config.js`
`withLogtail()` using the [`@logtail/next`](https://www.npmjs.com/package/@logtail/next) library. Follow
[their quick start](https://betterstack.com/docs/logs/javascript/nextjs/) if you want to do the same. I'm also a fan of their beautiful UI and how easy it is to
send meaningful logs. All I have to do is attach objects to a log line and they show up as searchable json objects.

```typescript
let logger = log.with({ env: process.env.NODE_ENV });
const response = await openAI.chat.completions.create(chatCompletionRequest);
logger = logger.with({ response });
logger.info("successfully returned");
```

I am also a big fan of services that offer a free tier that just helps you to verify the technology without paying for it just yet. Perfect for side projects
like this and you'll see this schema throughout the technologies I chose for this project.

### Emails with [Plunk](https://useplunk.com/)

One more thing I wanted to try out and have as a building block for future projects was a wait list feature that allows me to collect email addresses and send
emails to all collected addresses later on. I looked into services like [getwaitlist.com](https://getwaitlist.com/), but really thought this feature was simple
enough to build myself, which would also offer me more flexibility as to how it looks.

<img src="/assets/posts/waitlist.png" width="80%" style="display: block; margin-left: auto; margin-right: auto;"/>

First, I really wanted the glassmorphism background for the modal, which makes the background look blurry. I used this as the modal, inspired by the
[daisyUI modal](https://daisyui.com/components/modal/).

```html
<form method="dialog" className="modal-backdrop bg-opacity-10 bg-clip-padding backdrop-blur-md backdrop-filter">
  <button>close</button>
</form>
```

Then I used [Plunk](https://useplunk.com/) to send the emails upon submit. Of course the code to send emails has to live on the server, so that no tokens get
exposed to the client. So I used [Next.js server actions](https://nextjs.org/docs/app/api-reference/functions/server-actions). That's essentially just a
function call that you can do in the client code, but it calls a function that is marked with `"use server"` and so the compiler will only add this into the
server code. From there I was just able to call the Plunk API to send the emails.

```typescript
const { success } = await plunk.emails.send({
  to: email,
  subject: "🚀 Welcome to nextUX!",
  subscribed: true,
  body,
});
```

One additional cool thing I wanted to mention here is that even the email body itself is a React component, built with [`react-email`](https://react.email/).

### Testing with [JEST](https://jestjs.io/) and [POLLY.JS](https://netflix.github.io/pollyjs)

I'm a big fan of starting with tests early on in a project. It just helps so much for test-driven development, which is to start with tests first and then fill
in the actual code. This means that every bit of code can be executed right away with a debugger. Jest is a great and well-proven framework to define your tests
and execute them. In my case I like to have my test files right next to the actual code files. This is different to most TypeScript projects I've seen, where
test files are often in a `/test` directory. But I really like how the Go community is doing tests, where every test file is a sibling to the actual code file.
So I would always have to files like `route.ts` and `route.test.ts`.

For code that calls APIs, like in my case the Whisper and Chat Completion API by OpenAI, you don't want to call the actual API every time you run your tests. It
would create unnecessary costs and would make your tests fail if the upstream dependency is down. For that I love to do API integration tests with API
recordings. I've previously used this principle in various go projects using [`dnaeon/go-vcr`](https://github.com/dnaeon/go-vcr). It essentially functions like
a real VCR, where you first record a real API call against the actual upstream during development. Every aspect of the API call such as the URL, headers,
request and response body is recorded and stored in a json file. Then during tests, the actual API call is replaced with a mock that reads the recorded json
file and returns the response from there. This way you can run your tests without having to call the actual API. And if you want to update the API call, you can
just delete the recorded json file and run the test again. It will then record the API call again and store it in a new json file. This way you can easily
update your API calls and make sure they still work as expected.

I have found [`POLLY.JS`](https://netflix.github.io/pollyjs) for this project, which is the JavaScript equivalent to `go-vcr`. It works very similar and is
replaying the OpenAI API calls upon every test run. I used the following functions to strip API calls of any credentials, so that they don't get checked into my
repository:

```typescript
const stripTokens = (_: any, recording: any) => {
  if (recording) {
    if (recording.request) {
      if (recording.request.headers) {
        recording.request.headers = recording.request.headers.map((header: { name: string; value: string }) => {
          if (header.name === "authorization") {
            header.value = "Bearer: test-token";
          }
          return header;
        });
      }
    }
  }
};
```

This can then be used in a regular jest test like this:

```typescript
beforeEach(() => {
  const { server } = context.polly;
  server.any().on("beforePersist", stripTokens);
});
```

### API Types Defined with [protobuf](https://protobuf.dev/)

The API types are defined using [protobuf](https://protobuf.dev/) and the source of truth is stored in `.proto` files. The fields are then annotated with
[`ts-to-zod`](https://www.npmjs.com/package/ts-to-zod) annotations. I then added a script to my `package.json` that generates TypeScript types and `zod` schema
from the protos:

```bash
protoc --proto_path=./proto --plugin=./node_modules/.bin/protoc-gen-ts_proto --ts_proto_out=./src/app/lib/proto ./proto/*.proto && ts-to-zod --all
```

This part could have been technically done the same way as described above, with Next.js server actions. But I really wanted a re-usable API, that's also
callable from outside it's dedicated UI. Protobufs are perfect for this, as you can create the client, server and documentation from the same source of truth.
So far I'm only using it to generate the same types and validation to use in the client and the server, but one thing I'd like to try out in the future is to
create the actual Next.js routes from proto files using [Connect](https://connectrpc.com/). A great example of what I mean can be found
[here](https://github.com/connectrpc/examples-es/tree/main/nextjs).

### CI/CD with [GitHub Actions](https://github.com/features/actions)

Lastly, I'm obviously using [GitHub](https://github.com) to check in my code and have setup GitHub actions to run a workflow upon every commit. The workflow is
super simple and runs the linter and the tests:

```yaml
name: Main

on:
  push:

jobs:
  lint-test:
    name: Lint & Test
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      - name: Set up Node.js 18
        uses: actions/setup-node@v3
        with:
          node-version: 18.16.1
      - name: Install Dependencies
        run: npm install
      - name: Run Lint
        run: npm run lint
      - name: Run Tests
        run: npm test
```

The [Vercel GitHub integration](https://vercel.com/docs/deployments/git/vercel-for-github) then takes care of the deployment and the previews.

### Conclusion

And that's it for now. I hope you enjoyed this write-up and maybe even can derive something that you can use on your upcoming projects. If you have any
suggestions for improvements, reach out to me on [X @jonnylangefeld](https://x.com/jonnylangefeld).

## Features

- Out of the box interactions such as scale, move, rotate, skew, group...
- Built in shapes, controls, animations, image filters, gradients, patterns, brushes...
- `JPG`, `PNG`, `JSON` and `SVG` i/o
- Typed and modular
- [Unit tested](CONTRIBUTING.md#-testing)
- Security efforts [![OpenSSF Best Practices](https://www.bestpractices.dev/projects/12579/badge)](https://www.bestpractices.dev/projects/12579)

#### Supported Browsers/Environments

|   Context   | Supported Version | Notes                           |
| :---------: | :---------------: | ------------------------------- |
|   Firefox   |        ✔️         | 58                              |
|   Safari    |        ✔️         | 11                              |
|    Opera    |        ✔️         | chromium based                  |
|   Chrome    |        ✔️         | 64                              |
|    Edge     |        ✔️         | chromium based                  |
| Edge Legacy |        ❌         |
|    IE11     |        ❌         |
|   Node.js   |        ✔️         | [Node.js installation](#nodejs) |

Fabric.js does not use polyfills by default, or tries to keep it at minimum. the browser version we support is determined by the level of canvas api we want to use and some js syntax. While JS can be easily transpiled, canvas API can't.

## Installation

For new applications, install the environment-specific package:

```bash
# Browser applications
npm install @fabricjs/browser

# Node.js applications
npm install @fabricjs/node
```

The legacy `fabric` package remains supported for existing applications:

```bash
$ npm install fabric --save
# or use yarn
$ yarn add fabric
# or use pnpm
$ pnpm add fabric
```

## Packages and migration

| Package             | Role                                                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `fabric`            | Legacy compatibility facade. It re-exports `@fabricjs/browser`.                                                                 |
| `@fabricjs/browser` | Preferred entrypoint for new browser applications.                                                                              |
| `@fabricjs/node`    | Preferred entrypoint for new Node.js applications. It owns the Node-specific dependencies.                                      |
| `@fabricjs/core`    | Shared, environment-neutral runtime used by the browser and Node packages. It is intended for advanced and shared dependencies. |
| Extension packages  | Optional features imported individually, such as `@fabricjs/aligning-guidelines`.                                               |

Existing imports continue to work:

```js
import { Canvas } from 'fabric';
import { StaticCanvas } from 'fabric/node';
```

New applications should prefer the explicit entrypoints:

```js
import { Canvas } from '@fabricjs/browser';
import { StaticCanvas } from '@fabricjs/node';
import { AligningGuidelines } from '@fabricjs/aligning-guidelines';
```

The `fabric` and `fabric/node` facades share the same class identities as
their corresponding workspace packages. Keep `fabric` and every
`@fabricjs/*` package on matching versions; mixing mismatched versions can
load separate runtimes.

`@fabricjs/core` has no Node-specific runtime dependencies, but it is not a
DOM-free API. Advanced consumers using core APIs that touch DOM or canvas must
provide a suitable environment implementation.

### Legacy distribution files

The ESM `fabric` and `fabric/node` entries are small compatibility facades over
the workspace packages. The legacy standalone files remain available for
existing usage:

- `dist/index.js` and `dist/index.min.js` are full browser UMD builds from
  `@fabricjs/browser`, for `<script>` tags and `require('fabric')`.
- `dist/index.node.cjs` is the legacy CommonJS compatibility build for
  `require('fabric/node')`.

New ESM applications should continue to import `@fabricjs/browser` or
`@fabricjs/node` directly.

#### Browser

[![cdnjs](https://img.shields.io/cdnjs/v/fabric.js.svg)][cdnjs]
[![jsdelivr](https://data.jsdelivr.com/v1/package/npm/fabric/badge)][jsdelivr]

See [browser modules][mdn_es6] for using es6 imports in the browser or use a dedicated bundler.

#### Node.js

We strongly recommend to run your applications only LTS versions of node.

Said so the minimum supported version of node is 20.
We bump up the minimum version of node with a Major release only when the dependencies force us to do so.

Fabric.js depends on [node-canvas][node_canvas] for a canvas implementation (`HTMLCanvasElement` replacement) and [jsdom][jsdom] for a `window` implementation on node.
This means that you may encounter `node-canvas` limitations and [bugs][node_canvas_issues].

Follow these [instructions][node_canvas_install] to get `node-canvas` up and running.

## Quick Start

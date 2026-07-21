---
name: mermaid-diagram
description: Generate Mermaid diagrams (flowchart/activity, sequence, architecture, deployment, class, state, ER) from a text description or from source code, with high-contrast styling and syntax validation. Trigger on "create a diagram", "generate a mermaid diagram", "document this architecture", "show this as a flowchart/sequence diagram", "diagram this code/workflow/API flow", "convert code to a diagram", or when a design doc needs an embedded diagram.
---

# Mermaid Diagram Generator

Pick the diagram type the request actually needs, generate valid Mermaid syntax with readable (high-contrast) styling, and validate before handing it back — a diagram that fails to render is worse than no diagram.

## 1. Pick the Diagram Type

| Request sounds like | Diagram type | Mermaid syntax |
|---|---|---|
| Workflow, process, business logic, user flow, decision points | Activity/flowchart | `flowchart TD` (or `LR`) |
| API calls, service-to-service interaction, request/response order | Sequence | `sequenceDiagram` |
| System components, module boundaries, high-level structure | Architecture | `flowchart TB` with subgraphs, or `architecture-beta` |
| Infrastructure, cloud resources, network topology, k8s | Deployment | `flowchart TB` with subgraphs per environment/zone |
| Class/type relationships, OOP structure | Class | `classDiagram` |
| Finite states and transitions | State | `stateDiagram-v2` |
| Entity relationships, schema | ER | `erDiagram` |
| Timeline, project schedule | Gantt | `gantt` |

When code is provided instead of a description, read it first — for architecture, follow the layer boundaries (controller/service/repository, component tree, pipeline stages) already in the code rather than inventing new groupings; for sequence, follow the actual call order.

Full syntax reference and a worked example per type is in `references/details.md` — read the section for the chosen type before writing the diagram body.

## 2. Style for Readability

- **Every `classDef` sets an explicit `color:`.** Mermaid's default theme text color doesn't always contrast against a custom `fill:` — a light fill needs a dark `color:`, a dark fill needs a light one. This is the single most common "the diagram renders but you can't read half of it" bug.
- **One diagram, one concept.** If a request needs both "how the request flows" and "what infrastructure it runs on," that's a sequence diagram and a deployment diagram, not one diagram trying to be both.
- **Label edges when the label carries information** (`-->|"validates"|`), skip it when the arrow direction alone says everything.

### Size and Complexity Guardrail

A diagram exists so someone can understand a system faster than reading the code or the prose — one that needs to be scrolled, zoomed, or squinted at has stopped doing that job. Fit it on a single screen at a readable size:

- **~15-20 nodes is the practical ceiling** for a flowchart, sequence, or architecture diagram before it stops being scannable in one glance. If the real system genuinely has more moving parts than that, that's a sign the request wants *several* diagrams at different zoom levels (one overview + one detail diagram per subsystem), not one diagram trying to hold all of it.
- **Collapse repetition.** Three near-identical worker nodes doing the same job become one node labeled `Worker (×3)`, not three copies cluttering the canvas — detail that doesn't change the reader's understanding of the system isn't worth the space it takes.
- **Prune to the concept being explained.** A deployment diagram answering "where does this run" doesn't need every IAM policy and env var — only the parts that inform *that* question. Leaving out accurate-but-irrelevant detail is not the same as leaving out something that would change the reader's understanding.
- **If it still doesn't fit, split it** — an overview diagram with subgraphs collapsed to single boxes, linked to a separate detail diagram per subgraph, beats one dense diagram nobody can parse. Say so rather than forcing everything onto one canvas.

### Which Emoji for Which Node

Unicode symbols exist to mark node *kind* at a glance, not to decorate — a reader should be able to tell "that's a datastore" or "that's external" from the icon alone, before reading the label. Pick from the fixed vocabulary below and use each symbol for the *same* kind of node everywhere in the diagram; skip symbols entirely on a dense diagram where they'd just add clutter, rather than using them inconsistently.

| Kind | Symbol | Use for |
|---|---|---|
| Actor / user | 👤 | End user, external human actor |
| Client / frontend | 🖥️ / 📱 | Web app, mobile app, browser |
| Gateway / edge | 🌐 | API gateway, load balancer, CDN, ingress |
| Compute | ⚙️ | App server, service, worker, function/lambda |
| Async job | 🔄 | Background job, scheduled task, retry loop |
| Relational DB | 💾 | Postgres, MySQL, RDS — durable structured storage |
| Cache | ⚡ | Redis, Memcached, in-memory store |
| Object storage | 📦 | S3, GCS, blob storage, file store |
| Queue / message bus | 📬 | Kafka, SQS, RabbitMQ, pub/sub topic |
| Auth / security | 🔐 | Auth service, IAM, secrets manager, token issuer |
| External / third-party | ☁️ | Any service outside the system boundary — payment processor, external API |
| Network boundary | 🌍 | Internet, public network edge |
| Monitoring / logging | 📊 | Metrics, dashboards, log aggregation |
| Alert / failure state | ⚠️ / ❌ | Error path, failure branch, alert |
| Success / terminal state | ✅ | Completed, confirmed, terminal success node |
| Payment / billing | 💳 | Charge, invoice, billing step (activity diagrams) |
| Notification | 📧 / 📬 | Email, push notification, webhook fired |

If a node doesn't clearly fit one of these categories, leave it unlabeled rather than reaching for an unrelated emoji — a wrong or generic symbol is worse than no symbol, because the reader will try to make it mean something.

## 3. Validate Before Handing It Back

Never present a diagram you haven't checked will actually render. If the Mermaid CLI is available:

```bash
npx -y @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png -b transparent
```

A non-zero exit or stderr output means a syntax error — fix it before showing the result, don't ask the user to debug rendering. If `mmdc` isn't available (no npm/network), at minimum re-read the generated syntax against `references/details.md`'s gotchas section (reserved words, arrow syntax, unescaped special characters) — these account for most Mermaid parse failures.

## 4. Output

Default to a fenced ` ```mermaid ` code block inline in the response or target markdown file — that's what renders directly in GitHub, most editors, and Claude's own UI. Only produce a standalone `.mmd` file (and PNG/SVG via `mmdc -i in.mmd -o out.png`) when the user is embedding the diagram somewhere that needs a static image, e.g. Confluence, a slide deck, or a doc format that doesn't render Mermaid natively.

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
- **Unicode symbols add scannability, not decoration** — use them to mark node *kind* consistently (☁️ external service, 💾 datastore, 🔐 auth/security, 👤 actor, ⚙️ compute, 📬 queue), not as one-off flourish. Skip them entirely if the diagram is dense enough that symbols would just add clutter.
- **Label edges when the label carries information** (`-->|"validates"|`), skip it when the arrow direction alone says everything.

## 3. Validate Before Handing It Back

Never present a diagram you haven't checked will actually render. If the Mermaid CLI is available:

```bash
npx -y @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png -b transparent
```

A non-zero exit or stderr output means a syntax error — fix it before showing the result, don't ask the user to debug rendering. If `mmdc` isn't available (no npm/network), at minimum re-read the generated syntax against `references/details.md`'s gotchas section (reserved words, arrow syntax, unescaped special characters) — these account for most Mermaid parse failures.

## 4. Output

Default to a fenced ` ```mermaid ` code block inline in the response or target markdown file — that's what renders directly in GitHub, most editors, and Claude's own UI. Only produce a standalone `.mmd` file (and PNG/SVG via `mmdc -i in.mmd -o out.png`) when the user is embedding the diagram somewhere that needs a static image, e.g. Confluence, a slide deck, or a doc format that doesn't render Mermaid natively.

---
name: openapi-spec
description: Write and validate OpenAPI 3.1 specifications for RESTful APIs — no code generation, spec document only. Covers reusable components ($ref schemas/parameters/responses/security schemes) and Spectral/Redocly lint rules. Trigger on "write an OpenAPI spec", "generate an OpenAPI/Swagger doc", "put this API contract into openapi.yaml", "validate my openapi.yaml", or when a `.yaml`/`.json` file under a `paths:`/`openapi:` key is being written or reviewed. If the resource shape, URL/versioning strategy, or REST-vs-GraphQL choice hasn't been decided yet, that's the `dev-api-design` skill, not this one.
---

# OpenAPI Spec Generation

Patterns for writing OpenAPI 3.1 specs as a design artifact — the contract for an API, not code, and not generated from code. Write it by hand, keep it internally consistent, validate it.

## When to Use

- Designing an API contract before (or instead of) implementation
- Documenting an existing REST API by hand
- Reviewing a spec for consistency, missing error responses, or naming drift
- Validating a spec against style/lint rules

Assumes the resource shape and design decisions (REST vs. GraphQL, versioning strategy, pagination style) are already made — if they aren't, use `dev-api-design` first, then come back here to encode the result.

## 3.1 Structure Baseline

```yaml
openapi: 3.1.0
info:
  title: API Title
  version: 1.0.0
servers:
  - url: https://api.example.com/v1
paths:
  /resources:
    get: ...
components:
  schemas: ...
  parameters: ...
  responses: ...
  securitySchemes: ...
```

3.1 is JSON Schema-aligned (unlike 3.0) — `nullable` is gone in favor of `type: [string, "null"]`, and `examples` can be an array on any schema, not just a single `example`. Don't write 3.0-style `nullable: true` into a 3.1 doc.

A full annotated skeleton (paths, reusable schemas/parameters/responses, security schemes) is in `references/details.md` — read it before hand-writing a component from scratch.

## Rules

- **Reuse via `$ref`.** A schema, parameter, or response used more than once goes in `components/` and gets referenced — never copy-pasted across paths. Duplication here is what makes specs rot.
- **Every response needs a schema, including errors.** List every status code the endpoint can actually return, not just 200/201 — 400/401/403/404/409/422/500 as applicable, each with its real error shape.
- **Security is explicit per operation.** Define every scheme used in `components/securitySchemes`, and set `security:` on each operation (or globally with per-operation overrides for public endpoints) — don't leave it implied.
- **Examples are real values**, not `"string"` or `"foo"`. A consumer copies the example to make their first request; a placeholder value makes that request fail.
- **Version the API**, not just the spec — in the URL path or a header, and bump `info.version` with semver when the contract changes.
- **Consistent naming.** Pick one casing convention (usually `camelCase` for JSON properties, `kebab-case` for paths) and hold it across every path and schema.
- **No hardcoded environment URLs** — use `servers:` entries (and server variables for path segments like region/tenant) instead of baking a single host into the doc.

## Validating

Lint the spec before trusting it — Spectral (`spectral lint openapi.yaml`) or Redocly (`redocly lint openapi.yaml`) catch missing descriptions, inconsistent naming, undocumented error responses, and security gaps that manual review misses. Rule-set starting points are in `references/details.md`.

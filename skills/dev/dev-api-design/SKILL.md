---
name: dev-api-design
description: REST and GraphQL API design principles — resource-oriented URL/method design, pagination, filtering, error formats, versioning, HATEOAS, localization/i18n (Accept-Language negotiation, locale fallback, translated content shape, locale-invariant IDs), GraphQL schema-first development, resolvers, DataLoader/N+1 prevention, and Relay-style cursor pagination. Trigger on "design this API", "REST or GraphQL", "how should I version this API", "how do I localize this API", "support multiple languages/locales", "review this API design", "API design standards", or when picking resource shape/URL structure/pagination/locale strategy before or during dev-design's API-contract axis. For writing the actual OpenAPI 3.1 spec document, use the `openapi-spec` skill instead.
---

# API Design Principles

Design principles for REST and GraphQL APIs that stay usable as they grow — consistent enough that a developer can guess the next endpoint's shape from the ones they've already seen.

## When to Use

- Designing a new REST or GraphQL API's resource/schema shape
- Refactoring an existing API for consistency or usability
- Setting API design standards for a team
- Reviewing an API design before implementation
- Deciding REST vs. GraphQL for a given use case
- Picking a versioning or deprecation strategy

Use `dev-design` first to decide whether an API contract axis is even in scope; this skill is what fills that axis in once it is. Once the design is settled and the paradigm is REST, hand off to the `openapi-spec` skill to write the actual `openapi.yaml` — this skill decides the shape, that one writes the document.

## REST: Resource-Oriented Design

- **Resources are nouns, not verbs.** `/orders`, not `/getOrders` or `/createOrder`. The HTTP method carries the verb.
- **HTTP methods carry fixed semantics** — don't repurpose them:
  | Method | Meaning | Idempotent | Safe |
  |---|---|---|---|
  | GET | Retrieve | Yes | Yes |
  | POST | Create (or non-idempotent action) | No | No |
  | PUT | Replace the whole resource | Yes | No |
  | PATCH | Partial update | No* | No |
  | DELETE | Remove | Yes | No |

  \* PATCH *can* be made idempotent (e.g. JSON Merge Patch to a fixed value) but isn't guaranteed to be — don't rely on retry-safety without checking.
- **URLs represent hierarchy**, not query logic: `/users/{id}/orders`, not `/orders?userId={id}` when the relationship is the point of the request (both can coexist — the nested route for "this user's orders", a top-level filtered route for "orders across users").
- **Plural nouns for collections** — `/users` not `/user` — consistently, not "plural when convenient."
- **Pagination is not optional on any collection endpoint.** Cursor-based for anything that mutates while paginated (feeds, logs); offset/limit is fine for small, stable collections. Always return a way to get the next page — don't make the client compute offsets by hand.
- **Filtering and sorting via query params**, not new endpoints: `/orders?status=pending&sort=-createdAt`, not `/orders/pending`.
- **Errors are structured and consistent** across every endpoint — same shape for a 400 on `/users` as a 400 on `/orders`. Status code communicates the category (4xx client, 5xx server); the body carries the specifics (code, message, field-level detail).
- **Statelessness.** Every request carries everything needed to process it — no server-side session state a load balancer has to route around.

Detailed patterns (URL design worked examples, error-body schema, cursor pagination mechanics, rate-limit headers) are in `references/details.md`.

## GraphQL: Schema-First Design

- **Design the schema before writing resolvers.** The schema is the contract; resolvers are an implementation detail behind it. Get the types, queries, and mutations reviewed before wiring up data fetching.
- **Queries read, mutations write, subscriptions push.** Don't put side effects in a query resolver — a client (or a cache) may call it more than once or speculatively.
- **Avoid N+1 with DataLoader (or equivalent batching).** A naive resolver that fetches one row per parent in a list will issue one query per item — batch and cache per-request instead. This is the single most common GraphQL performance bug.
- **Cursor-based pagination, Relay-style**, for any list that can grow: `edges { node, cursor }`, `pageInfo { hasNextPage, endCursor }`. Offset pagination breaks under concurrent inserts the same way it does in REST.
- **Structured errors in mutation payloads**, not just the top-level `errors` array — a mutation's response type should carry its own `errors: [UserError!]` field so a client can show field-level validation feedback without inspecting the transport-level error list.
- **`@deprecated(reason: "...")` for gradual migration** — never delete a field clients may still query; deprecate, monitor usage, remove once usage hits zero.
- **Validate at both the schema and the resolver.** Schema types catch shape errors for free; business-rule validation (uniqueness, cross-field constraints) still needs resolver-level checks.

Detailed patterns (schema/resolver worked example, DataLoader implementation sketch, Relay connection shape) are in `references/details.md`.

## Versioning

| Strategy | Example | Tradeoff |
|---|---|---|
| URL | `/api/v2/users` | Most visible and cacheable; forces a new route tree per version |
| Header | `Accept: application/vnd.api+json; version=2` | Keeps URLs stable; version is invisible in logs/browser, easy to miss |
| Query param | `/users?version=2` | Simple but easy to omit accidentally, defaults become a footgun |

Pick one per API and stay consistent — mixing strategies within the same API is itself a design smell. Plan for breaking changes from day one: additive changes (new optional field, new endpoint) don't need a version bump; removing or renarrowing a field does.

**HATEOAS** (hypermedia links in responses, e.g. `_links: { next, self }`) is worth it when clients need to discover valid next actions dynamically (workflow-driven APIs); skip it for typical CRUD APIs where the client already knows the routes — the added response weight and client complexity isn't worth it there.

## Localization

An API serving more than one language or region needs the locale to be an explicit, negotiated input — not something inferred from IP or bolted on later.

- **Negotiate locale via `Accept-Language`** (standard `Accept-Language: fr-CA, fr;q=0.8, en;q=0.5` header) for content that adapts per-request, same as content negotiation for format. Fall back to a query param (`?locale=fr-CA`) only when the client can't set headers (e.g. a plain browser link that needs to be shareable) — don't make it the primary mechanism, it's easy to omit and then silently wrong.
- **Return the resolved locale**, not just the requested one — a `Content-Language` response header (or a `locale` field in the body) tells the client what it actually got when the exact locale wasn't available and a fallback was used.
- **Define the fallback chain up front**: `fr-CA` → `fr` → default locale, not a hardcoded per-endpoint guess. Apply it consistently across every localized endpoint.
- **Locale-sensitive formatting is the server's job for machine-readable fields, the client's for display.** Return dates in ISO 8601 (`2026-07-21T10:00:00Z`) and currency as an ISO 4217 code plus a numeric minor-unit amount (`{ "currency": "JPY", "amount": 500 }`), not a pre-formatted locale-specific string — let the client format for display. Only return pre-formatted strings when the field is genuinely just text (a translated label), not a value the client might compute with.
- **Translated content lives in a predictable shape**, not a different field name per language. Prefer a nested object (`name: { en: "Widget", fr: "Gadget" }`) for a fixed known set of locales, or return exactly one locale's value already resolved per the negotiated header for large/open locale sets — don't expand every localizable field into `name_en`, `name_fr`, `name_de` columns in the response schema, that doesn't scale past a handful of languages.
- **Error messages are user-facing text and need the same localization as any other content.** Return a stable machine-readable `code` (never localized — clients branch on this) alongside a `message` that *is* localized per the negotiated `Accept-Language`. Never make a client parse a translated string to decide what went wrong.
- **Don't localize identifiers.** IDs, slugs (when used as keys, not display text), enum values, and status codes stay locale-invariant — only display strings and formatted values change with locale.

## Common Pitfalls

- **Over-/under-fetching (REST).** A list endpoint returning full objects when the client needed three fields, or requiring five round trips to assemble one screen. GraphQL exists partly to fix this — but brings its own N+1 problem if resolvers aren't batched.
- **Breaking changes without a version or deprecation path.** Removing or renaming a field a client depends on, with no warning period.
- **Inconsistent error formats** across endpoints — different shape for validation errors vs. auth errors vs. 500s makes client error-handling code balloon.
- **Missing rate limits** — an API with no limits is one slow client away from an incident.
- **Ignoring HTTP semantics** — POST for something that should be idempotent, GET with side effects (breaks caching and prefetching).
- **API structure mirroring the database schema.** A join table, an internal soft-delete flag, or a denormalized column showing up directly in the API is a leak of implementation detail that will outlive the schema decision that caused it.

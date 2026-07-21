# API Design — Detailed Patterns

Worked examples for `dev-api-design`. Adapt names/types, don't paste unmodified.

## REST

### URL Design

```text
GET    /orders                  # list (paginated)
POST   /orders                  # create
GET    /orders/{id}             # retrieve one
PATCH  /orders/{id}             # partial update
DELETE /orders/{id}             # remove
GET    /orders/{id}/items       # nested collection — "this order's items"
POST   /orders/{id}/cancel      # non-CRUD action on a resource: verb as a sub-resource, not a query param
```

`POST /orders/{id}/cancel` rather than `PATCH /orders/{id} {status: "cancelled"}` when cancellation has side effects (refund, notification) beyond a field change — the action deserves its own endpoint so it can have its own validation, auth check, and audit log entry.

### Cursor Pagination

```json
GET /orders?limit=20&cursor=eyJpZCI6MTIzfQ

{
  "items": [ /* 20 orders */ ],
  "nextCursor": "eyJpZCI6MTQzfQ",
  "hasMore": true
}
```

The cursor encodes the last-seen sort key (often base64 of `{"id": 123, "createdAt": "..."}`), not a raw offset — so items inserted or removed between requests don't shift the page boundary.

### Structured Error Body

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Request failed validation",
    "details": [
      { "field": "email", "issue": "must be a valid email address" },
      { "field": "quantity", "issue": "must be at least 1" }
    ]
  }
}
```

Same top-level shape (`error.code`, `error.message`, optional `error.details`) on every error response, regardless of endpoint or status code — a client writes one error-handling path, not one per endpoint.

### Rate Limit Headers

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 42
X-RateLimit-Reset: 1730000000
```

Return these on every response (not just when the limit is hit) so clients can back off proactively instead of learning the limit by triggering a 429.

## GraphQL

### Schema-First Example

```graphql
type Order {
  id: ID!
  status: OrderStatus!
  items: [OrderItem!]!
  createdAt: DateTime!
}

enum OrderStatus {
  PENDING
  SHIPPED
  CANCELLED @deprecated(reason: "Use REFUNDED for cancelled+refunded orders")
}

type OrderConnection {
  edges: [OrderEdge!]!
  pageInfo: PageInfo!
}

type OrderEdge {
  node: Order!
  cursor: String!
}

type PageInfo {
  hasNextPage: Boolean!
  endCursor: String
}

type Query {
  orders(first: Int!, after: String): OrderConnection!
}

type CreateOrderPayload {
  order: Order
  errors: [UserError!]!
}

type UserError {
  field: [String!]
  message: String!
}

type Mutation {
  createOrder(input: CreateOrderInput!): CreateOrderPayload!
}
```

### DataLoader (N+1 prevention)

```typescript
import DataLoader from 'dataloader';

// One batched query per request tick, not one query per resolver call.
const orderItemsLoader = new DataLoader<string, OrderItem[]>(async (orderIds) => {
  const items = await db.orderItems.findMany({ where: { orderId: { in: orderIds } } });
  const byOrder = groupBy(items, 'orderId');
  return orderIds.map((id) => byOrder[id] ?? []);
});

const resolvers = {
  Order: {
    items: (order: Order) => orderItemsLoader.load(order.id),
  },
};
```

Create one loader instance per request (not a shared singleton) so caching doesn't leak data across requests/users.

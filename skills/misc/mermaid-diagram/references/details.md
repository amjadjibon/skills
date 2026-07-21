# Mermaid Diagram Templates

Worked examples per diagram type for `mermaid-diagram`, plus the syntax gotchas that account for most render failures. Adapt node names/labels, don't paste unmodified.

## Activity / Flowchart

```mermaid
flowchart TD
    Start([🚀 Start]) --> Validate{✓ Valid input?}
    Validate -->|Yes| Process[⚙️ Process order]
    Validate -->|No| Reject[❌ Reject]
    Process --> Charge[💳 Charge payment]
    Charge --> Notify[📬 Send confirmation]
    Notify --> Done([✅ Complete])
    Reject --> Done

    classDef success fill:#90EE90,stroke:#333,stroke-width:2px,color:darkgreen
    classDef error fill:#FFB6C1,stroke:#DC143C,stroke-width:2px,color:black
    class Done,Process,Charge,Notify success
    class Reject error
```

Use `{}` for decision points, `()` / `([])` for start/end, `[]` for a process step. Keep one flowchart per concept — if it needs a legend to explain two unrelated flows sharing a canvas, split it.

## Sequence

```mermaid
sequenceDiagram
    actor User
    participant API as 🌐 API Gateway
    participant Auth as 🔐 Auth Service
    participant DB as 💾 Database

    User->>API: POST /login
    API->>Auth: validate credentials
    Auth->>DB: lookup user
    DB-->>Auth: user record
    Auth-->>API: JWT token
    API-->>User: 200 OK + token

    Note over Auth,DB: cached for 60s to cut repeat lookups
```

`->>` is a solid arrow (request), `-->>` is dashed (response) — keep that convention consistent so the diagram reads as a call/return pair without needing to read every label.

## Architecture

```mermaid
flowchart TB
    subgraph Client
        Web[🖥️ Web App]
    end
    subgraph "API Layer"
        Gateway[🌐 API Gateway]
        Auth[🔐 Auth Service]
    end
    subgraph "Data Layer"
        DB[(💾 Postgres)]
        Cache[(⚡ Redis)]
    end

    Web --> Gateway
    Gateway --> Auth
    Gateway --> DB
    Gateway --> Cache

    classDef layer fill:#87CEEB,stroke:#333,stroke-width:2px,color:darkblue
    class Gateway,Auth layer
```

Group by architectural layer with `subgraph`, not by arbitrary visual proximity — the subgraph boundary should mean something (a deployment unit, a team boundary, a network zone).

## Deployment

```mermaid
flowchart TB
    subgraph "VPC"
        subgraph "Public Subnet"
            LB[🌐 Load Balancer]
        end
        subgraph "Private Subnet"
            App1[⚙️ App Server 1]
            App2[⚙️ App Server 2]
        end
        DB[(💾 RDS Postgres)]
    end
    Internet((🌍 Internet)) --> LB
    LB --> App1
    LB --> App2
    App1 --> DB
    App2 --> DB
```

Mirror the actual network boundaries (public/private subnet, VPC, availability zone) as nested `subgraph`s — this is the one diagram type where the visual grouping should match infrastructure-as-code reality, not just conceptual grouping.

## Class

```mermaid
classDiagram
    class Order {
        +String id
        +OrderStatus status
        +addItem(item)
        +cancel()
    }
    class OrderItem {
        +String sku
        +Int quantity
    }
    Order "1" --> "*" OrderItem : contains
```

## State

```mermaid
stateDiagram-v2
    [*] --> Pending
    Pending --> Confirmed : payment succeeds
    Pending --> Cancelled : payment fails
    Confirmed --> Shipped
    Shipped --> Delivered
    Delivered --> [*]
    Cancelled --> [*]
```

## ER

```mermaid
erDiagram
    ORDER ||--|{ ORDER_ITEM : contains
    ORDER {
        string id PK
        string status
    }
    ORDER_ITEM {
        string sku PK
        int quantity
    }
```

## Syntax Gotchas (why most renders fail)

- **Reserved words as bare node IDs break the parser** — `end`, `class`, `style`, `default`, `subgraph`, `click` used unquoted as an identifier. Quote them: `"end"` not `end`.
- **Arrow syntax must be exact** — `-->` not `->`, `-.->`  for dashed, `==>` for thick. A single missing dash is a silent parse failure, not a warning.
- **Unescaped special characters in labels** (`"`, `(`, `)`, `:`, `#`, `%`) break rendering — wrap the label in quotes: `A["Say \"hello\""]`.
- **Every `subgraph` needs a matching `end`** — a missing `end` cascades into "unexpected token" errors on unrelated later lines, which makes the real cause easy to miss; count subgraphs vs. ends first when a flowchart won't parse.
- **`classDef`/`class` styling only takes effect with `color:` set explicitly** — Mermaid doesn't reliably auto-contrast text against a custom `fill:`.

## Validating and Converting

```bash
# Render to check for syntax errors (also produces the image if needed)
npx -y @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.png -b transparent

# SVG, custom theme
npx -y @mermaid-js/mermaid-cli -i diagram.mmd -o diagram.svg -t dark
```

A non-zero exit means the syntax is broken — read the stderr line number against the diagram source, check it against the gotchas above first before guessing.

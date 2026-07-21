# OpenAPI 3.1 Templates

Concrete templates for `openapi-spec`. Read the relevant section, adapt names/types, don't paste unmodified.

## 1. Complete Spec Skeleton

```yaml
openapi: 3.1.0
info:
  title: Widget API
  description: Manage widgets and their inventory.
  version: 1.0.0
  contact:
    name: API Team
    email: api@example.com
servers:
  - url: https://api.example.com/v1
    description: Production
  - url: https://staging-api.example.com/v1
    description: Staging

paths:
  /widgets:
    get:
      operationId: listWidgets
      summary: List widgets
      tags: [Widgets]
      parameters:
        - $ref: '#/components/parameters/PageParam'
        - $ref: '#/components/parameters/LimitParam'
      responses:
        '200':
          description: A page of widgets
          content:
            application/json:
              schema:
                type: object
                properties:
                  items:
                    type: array
                    items:
                      $ref: '#/components/schemas/Widget'
                  total:
                    type: integer
              examples:
                default:
                  value:
                    items: [{ id: "w_123", name: "Blue Widget", quantity: 42 }]
                    total: 1
        '401':
          $ref: '#/components/responses/Unauthorized'
    post:
      operationId: createWidget
      summary: Create a widget
      tags: [Widgets]
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/WidgetInput'
      responses:
        '201':
          description: Widget created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Widget'
        '400':
          $ref: '#/components/responses/BadRequest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '422':
          $ref: '#/components/responses/ValidationError'

  /widgets/{widgetId}:
    parameters:
      - name: widgetId
        in: path
        required: true
        schema:
          type: string
    get:
      operationId: getWidget
      summary: Get a widget
      tags: [Widgets]
      responses:
        '200':
          description: The widget
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Widget'
        '404':
          $ref: '#/components/responses/NotFound'

components:
  schemas:
    Widget:
      type: object
      required: [id, name, quantity]
      properties:
        id:
          type: string
          examples: ["w_123"]
        name:
          type: string
          examples: ["Blue Widget"]
        quantity:
          type: integer
          minimum: 0
        deletedAt:
          type: [string, "null"]
          format: date-time
    WidgetInput:
      type: object
      required: [name, quantity]
      properties:
        name:
          type: string
        quantity:
          type: integer
          minimum: 0
    Error:
      type: object
      required: [code, message]
      properties:
        code:
          type: string
        message:
          type: string
        details:
          type: array
          items:
            type: object
            properties:
              field: { type: string }
              issue: { type: string }

  parameters:
    PageParam:
      name: page
      in: query
      schema: { type: integer, minimum: 1, default: 1 }
    LimitParam:
      name: limit
      in: query
      schema: { type: integer, minimum: 1, maximum: 100, default: 20 }

  responses:
    BadRequest:
      description: Malformed request
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    Unauthorized:
      description: Missing or invalid credentials
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    NotFound:
      description: Resource does not exist
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    ValidationError:
      description: Request failed validation
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }

  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
    apiKeyAuth:
      type: apiKey
      in: header
      name: X-API-Key

security:
  - bearerAuth: []
```

## 2. Spectral Lint Rules

`.spectral.yaml`:

```yaml
extends: [[spectral:oas, all]]
rules:
  operation-operationId: error
  operation-description: error
  operation-tags: error
  no-$ref-siblings: error
  path-params-defined: error
  oas3-valid-media-example: error
  operation-4xx-response: error   # every operation documents at least one error response
  info-contact: warn
  openapi-tags: warn
```

Run: `spectral lint openapi.yaml --ruleset .spectral.yaml`

## 3. Redocly Lint Rules

`redocly.yaml`:

```yaml
apis:
  main:
    root: openapi.yaml
extends:
  - recommended
rules:
  no-invalid-media-type-examples: error
  operation-4xx-response: error
  operation-operationId: error
  path-declaration-must-exist: error
  security-defined: error
  no-unused-components: warn
```

Run: `redocly lint`

---
name: api-design-checklist
description: API design checklist covering security, versioning, idempotency, error standards, and OpenAPI conventions. Preloaded into the api-designer agent.
---

# API Design Checklist

## Design Review Checklist

**Resource Design**
```
[ ] Plural nouns for resources (/users, /orders, not /getUser, /createOrder)
[ ] Consistent naming: kebab-case in URLs, camelCase in JSON
[ ] Nested resources max 2 levels deep (/users/{id}/orders, not deeper)
[ ] Actions as sub-resources: POST /orders/{id}/cancel (not DELETE /orders/{id})
[ ] Query params for filtering/sorting: GET /orders?status=pending&sort=created_at
```

**HTTP Semantics**
```
[ ] GET is idempotent and safe (no side effects)
[ ] POST creates or triggers (not idempotent by default → add idempotency key)
[ ] PUT replaces entire resource (idempotent)
[ ] PATCH updates partial resource (not required to be idempotent)
[ ] DELETE removes resource (idempotent)
[ ] Correct status codes (201 for create, 204 for delete, 409 for conflict)
```

**Security**
```
[ ] All endpoints require auth (exception: health, public reads)
[ ] Auth token in Authorization header, not query param (logs leak)
[ ] HTTPS only — no HTTP
[ ] Rate limiting on all public endpoints (return 429 + Retry-After)
[ ] Input validation at boundary (schema, length, type, format)
[ ] No internal error details in 5xx responses
[ ] Request IDs on all responses (X-Request-ID or in body)
[ ] Sensitive data not in URLs (IDs ok, tokens/passwords never)
```

**Versioning**
```
[ ] Version in URL path: /v1/, /v2/
[ ] Deprecation headers on old versions: Deprecation: true, Sunset: <ISO date>
[ ] Sunset period: 6 months minimum (12 for high-traffic public APIs)
[ ] Breaking vs non-breaking changes classified before shipping
```

**Idempotency**
```
[ ] POST mutations support Idempotency-Key header
[ ] Idempotency stored for 24h minimum
[ ] Same key + different body → 422 (not silently different result)
[ ] Safe to retry: network timeouts won't double-charge/double-create
```

## Breaking vs Non-Breaking Changes

**Safe to ship without version bump:**
- Adding new optional response fields
- Adding new optional request query params
- Adding new endpoints
- Relaxing validation (required → optional)
- Adding new enum values (warn: strict parsers may break)

**Requires new version:**
- Removing or renaming fields
- Changing field types (`string` → `number`)
- Changing authentication method
- Adding required request fields
- Changing error response structure
- Removing endpoints
- Changing URL structure

## Standard Error Codes

```json
{
  "error": {
    "code": "VALIDATION_ERROR",      // machine-readable, SCREAMING_SNAKE_CASE
    "message": "Human-readable description for developers",
    "details": [                     // optional field-level errors
      { "field": "email", "message": "Invalid format" },
      { "field": "name",  "message": "Required" }
    ],
    "request_id": "req_01HXYZ123",   // always include for debugging
    "documentation_url": "https://docs.example.com/errors/VALIDATION_ERROR"
  }
}
```

**Common error codes:**
```
VALIDATION_ERROR      400 — request body/params invalid
AUTHENTICATION_REQUIRED 401 — no/invalid auth token
FORBIDDEN             403 — authed but not authorized
NOT_FOUND             404 — resource doesn't exist
CONFLICT              409 — duplicate, optimistic lock failure
UNPROCESSABLE         422 — valid format, invalid business rule
RATE_LIMITED          429 — too many requests
INTERNAL_ERROR        500 — unexpected server error
SERVICE_UNAVAILABLE   503 — overloaded, circuit open
```

## Rate Limiting Headers

```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 47
X-RateLimit-Reset: 1714521600

HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1714521600
Retry-After: 30
```

## Pagination Standards

```json
// Cursor-based (preferred for large/live data)
GET /v1/orders?cursor=eyJpZCI6MTIzfQ==&limit=50

{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTc4fQ==",
    "has_more": true
  }
}

// Offset (acceptable for admin UIs, small datasets)
GET /v1/reports?page=3&per_page=25

{
  "data": [...],
  "pagination": {
    "page": 3,
    "per_page": 25,
    "total_pages": 12,
    "total_count": 289
  }
}
```

## Async Operations Pattern

```http
// Request
POST /v1/reports/generate
Content-Type: application/json
{ "type": "monthly", "month": "2026-04" }

// Response — 202 immediately
HTTP/1.1 202 Accepted
Location: /v1/jobs/job-abc123
{
  "job_id": "job-abc123",
  "status": "pending",
  "poll_url": "/v1/jobs/job-abc123",
  "estimated_seconds": 30
}

// Poll
GET /v1/jobs/job-abc123
{ "status": "running", "progress": 0.42 }

// Complete
GET /v1/jobs/job-abc123
{ "status": "complete", "result_url": "/v1/reports/report-xyz" }
```

## OpenAPI Frontmatter Template

```yaml
openapi: 3.1.0
info:
  title: My API
  version: 1.0.0
  description: |
    Brief description of the API.
    
    ## Authentication
    All requests require `Authorization: Bearer <token>`.
    
    ## Rate Limits
    1,000 requests per hour per API key.

servers:
  - url: https://api.example.com
    description: Production
  - url: https://api.staging.example.com
    description: Staging

security:
  - BearerAuth: []

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  
  responses:
    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    NotFound:
      description: Resource not found
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
    RateLimited:
      description: Too many requests
      headers:
        Retry-After:
          schema: { type: integer }
      content:
        application/json:
          schema: { $ref: '#/components/schemas/Error' }
  
  schemas:
    Error:
      type: object
      required: [error]
      properties:
        error:
          type: object
          required: [code, message, request_id]
          properties:
            code:        { type: string }
            message:     { type: string }
            request_id:  { type: string }
            details:
              type: array
              items:
                type: object
                properties:
                  field:   { type: string }
                  message: { type: string }
```

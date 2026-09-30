# Expectation Fixtures — Matching Semantics

All `*.json` files in this folder describe the **exact** JSON body returned at the HTTP boundary, with two
placeholder conventions for values that are non-deterministic by design:

| Placeholder | Meaning | Assertion rule |
|---|---|---|
| `"<uuid>"` | A server-generated UUID string | Field MUST be present, non-null, and match `^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$` |
| `"<uploads-path>"` | The compatibility-only relative path `/uploads/<uuid><extension>` | Field MUST be present, non-null, and match `^/uploads/[0-9a-fA-F-]{36}\.(jpg\|jpeg\|png\|gif\|webp)$` |
| `"<iso-local-date-time>"` | Server-generated upload timestamp | Field MUST be present, non-null, and parseable as an ISO-8601 local date-time |

Every other value is asserted for **exact equality**. Key sets are asserted exactly — no extra keys,
no missing keys. Array ordering is significant and matches the order of the files in the multipart request.

# Deployment Configuration Contract (frozen)

This file pins the **externally observable** deployment configuration behavior that must be preserved across
the migration to Azure Container Apps. It is referenced by the configuration test cases in `test-cases.md`.

## HTTP listen port

| Property | Baseline value | Contract |
|---|---|---|
| Configured port | `8080` (`server.port=8080` in `application.properties` and `application-docker.properties`) | The application MUST bind its HTTP listener to the port resolved from configuration, and MUST serve `GET /` with status `200` on that port. |
| Override mechanism | Standard Spring Boot relaxed binding: environment variable `SERVER_PORT` overrides `server.port` | Setting `SERVER_PORT=<N>` MUST cause the application to serve `GET /` with status `200` on port `<N>`, and MUST NOT serve on `8080`. |
| Default when unset | `8080` | With no `SERVER_PORT` environment variable present, the application MUST serve on port `8080`. |

Post-migration note: Azure Container Apps injects the listen port; the contract above is exactly what makes
the application cloud-ready. The contract is technology-neutral — it does not prescribe *how* the port is
resolved, only that an environment-supplied port is honored and `8080` remains the default.

## Datasource credentials

| Property | Baseline value | Contract |
|---|---|---|
| `spring.datasource.url` | `${SPRING_DATASOURCE_URL:jdbc:oracle:thin:@oracle-db:1521/FREEPDB1}` | The datasource URL MUST be resolvable from the environment; no host, port or database name may be hard-coded without an environment override. |
| `spring.datasource.username` | `${SPRING_DATASOURCE_USERNAME:photoalbum}` | Username MUST be resolvable from the environment. |
| `spring.datasource.password` | `${SPRING_DATASOURCE_PASSWORD}` — **no default** | The password MUST NOT have a hard-coded default. Startup MUST fail when no credential is supplied AND the target does not use a password-less credential mechanism. |

Post-migration note: when the target uses a password-less mechanism (e.g. managed identity), the
`SPRING_DATASOURCE_PASSWORD` requirement is satisfied by the credential provider instead of a literal
secret. Either way, **no credential literal may appear in any file under `src/main/resources/`**.

## Admin credentials (protects state-changing endpoints)

| Property | Baseline value | Contract |
|---|---|---|
| `app.admin.username` | `${app.admin.username:admin}` | Resolvable from the environment (`APP_ADMIN_USERNAME`), defaulting to `admin`. |
| `app.admin.password` | `${app.admin.password}` — **no default** | MUST be supplied from the environment (`APP_ADMIN_PASSWORD`); no hard-coded default, no literal in source. |
| Auth scheme | HTTP Basic, stateless (no session), CSRF disabled | `POST /upload` and `POST /detail/*/delete` require HTTP Basic credentials; all other requests are anonymous-permitted. |

## Configuration-literal ban (static contract)

No file under `src/main/resources/` may contain a literal value for any of:
`spring.datasource.password`, `app.admin.password`.
They may only appear as unresolved placeholders (`${...}` with no default).
`src/test/resources/application-test.properties` is exempt — it holds non-production test values only.

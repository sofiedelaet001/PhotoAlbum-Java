# Infra Decision Table

> This document is part of the **frozen baseline bundle**. It records, for every external dependency the migrated application talks to, whether the post-migration tests will exercise it as a **real** provisioned resource, a **testcontainer**-backed emulator/dependency, or a **mock** at the SDK / HTTP boundary. The decision is made once here and reused as-is by the `verify-test-baseline` skill.

## Metadata

| Field | Value |
|-------|-------|
| Project | Photo Album (`com.photoalbum:photo-album:1.0.0`) |
| Module | `photo-album` (single module) |
| Migration Scope | Migrate from Oracle Database to Azure Database for PostgreSQL, and make deployment configuration (server port, credentials) cloud-ready for Azure Container Apps |
| Integration Test Environment | real |
| Created At | 2026-09-29 |
| `infra/` Snapshot | infra-missing |
| Status | baseline (frozen) |

> **Mode note.** The plan questionnaire records `Include integration testing? → Yes, real mode with provisioned infrastructure`. At the time this baseline was frozen no `infra/` directory exists in the repository and no provisioning task has run (provisioning is scheduled *after* task `001-setupBaseline`). Per the `create-test-baseline` decision rules, every dependency is therefore recorded as `mock` with reason `infra-missing`. Once infrastructure is provisioned and `infra/` is populated, switching any row to `real` requires an explicit **re-freeze cycle** of this bundle (unfreeze → amend → re-validate → re-freeze); `verify-test-baseline` must not silently re-decide.

## Decision Table

| Dependency | Infra Match | Decision | Auth Method | Reason |
|---|---|---|---|---|
| Azure Database for PostgreSQL — Flexible Server, database `photoalbum`, table `photos` (target of the Oracle migration; stores photo metadata and the `photo_data` BLOB/BYTEA payload) | No | mock | n/a | `infra-missing` — no `infra/` directory exists at freeze time, so no provisioned endpoint or credential is available to bind the datasource to. |
| Oracle Database Free 23ai — `jdbc:oracle:thin:@oracle-db:1521/FREEPDB1`, schema `photoalbum` (legacy datastore being replaced) | No | mock | n/a | `infra-missing` — legacy dependency is removed by the migration and no `infra/` entry exists; no post-migration test may bind to it. |

### Dependencies deliberately excluded

| Excluded item | Why it is not an external dependency row |
|---|---|
| `InMemoryUserDetailsManager` admin credential store (`SecurityConfig`) | In-process component; holds no network endpoint. Its *configuration* contract is pinned by TC-WEB-029 and TC-WEB-030 instead. |
| `cdn.jsdelivr.net` (Bootstrap CSS/JS `<link>` and `<script>` tags in the Thymeleaf templates) | Fetched by the browser, never by the application. No server-side call is made, so no test-time binding decision applies. |
| Local filesystem (`src/main/resources/static/uploads/`) | Legacy artifact only; `PhotoServiceImpl` stores bytes exclusively in the database column and writes no files. Pinned by the Negative Verification bullets of TC-WEB-005, TC-WEB-006, TC-WEB-011 and TC-WEB-013. |
| Azure Container Apps runtime | Hosting platform, not a dependency the application calls. Its only observable contract — honouring an environment-supplied listen port — is pinned by TC-WEB-028. |

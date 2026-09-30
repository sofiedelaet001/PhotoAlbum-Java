# Test Cases

> This document is the **frozen behavioral specification** of this module's external surface for the migration in scope. It is the source of truth that the `verify-test-baseline` skill uses to generate `*PostMigrationIT` tests against the new implementation. No test code is generated in the baseline phase.

## Metadata

| Field | Value |
|-------|-------|
| Project | Photo Album (`com.photoalbum:photo-album:1.0.0`) |
| Module | `photo-album` (single-module Maven project; test source root `src/test/`) |
| Migration Scope | Migrate from Oracle Database to Azure Database for PostgreSQL, and make deployment configuration (server port, credentials) cloud-ready for Azure Container Apps |
| Created At | 2026-09-29 |
| Status | baseline (frozen) |
| Testing Conventions | JUnit 5 (`org.junit.jupiter`) via `spring-boot-starter-test`; Spring Boot integration tests annotated `@SpringBootTest` + `@ActiveProfiles("test")`; test properties in `src/test/resources/application-test.properties`; package mirrors production (`com.photoalbum.*`); AssertJ assertions; no Testcontainers or custom helpers exist today |

## Existing Test Coverage

| Entry Point | Existing Test (FQ name) | Categories Covered |
|---|---|---|
| `com.photoalbum.PhotoAlbumApplication#main(String[])` (application bootstrap) | `com.photoalbum.PhotoAlbumApplicationTests#contextLoads` | happy-path (context wiring only; does not assert HTTP port binding or credential resolution) |

No other integration, IT or E2E tests exist in the repository. There is no existing `testdata`/fixture
directory, no Testcontainers usage, and no MockMvc/WebTestClient usage to align with; the conventions in
the Metadata table are therefore derived from the single existing test plus the build configuration.

## Entry-Point Inventory

| Entry Point | Type | Source (file:symbol) | Covered by |
|---|---|---|---|
| `GET /` | HTTP | `src/main/java/com/photoalbum/controller/HomeController.java:index` | TC-WEB-001, TC-WEB-002, TC-WEB-003, TC-WEB-004 |
| `POST /upload` | HTTP | `src/main/java/com/photoalbum/controller/HomeController.java:uploadPhotos` | TC-WEB-005 … TC-WEB-013, TC-WEB-031, TC-WEB-032 |
| `GET /detail/{id}` | HTTP | `src/main/java/com/photoalbum/controller/DetailController.java:detail` | TC-WEB-014, TC-WEB-015, TC-WEB-016, TC-WEB-017 |
| `POST /detail/{id}/delete` | HTTP | `src/main/java/com/photoalbum/controller/DetailController.java:deletePhoto` | TC-WEB-018, TC-WEB-019, TC-WEB-020, TC-WEB-021 |
| `GET /photo/{id}` | HTTP | `src/main/java/com/photoalbum/controller/PhotoFileController.java:servePhoto` | TC-WEB-022, TC-WEB-023, TC-WEB-024, TC-WEB-025, TC-WEB-026 |
| `com.photoalbum.PhotoAlbumApplication#main(String[])` | CLI | `src/main/java/com/photoalbum/PhotoAlbumApplication.java:main` | existing: `PhotoAlbumApplicationTests#contextLoads`, TC-WEB-027, TC-WEB-028, TC-WEB-029, TC-WEB-030 |

**Not entry points** (internal, reached only through the entry points above, therefore not specified
independently): `com.photoalbum.service.PhotoService` and its implementation,
`com.photoalbum.repository.PhotoRepository`, `com.photoalbum.util.MathUtil`,
`com.photoalbum.config.SecurityConfig` bean factory methods.

**Repository methods with no reachable entry point**: `PhotoRepository#findPhotosByUploadMonth`,
`PhotoRepository#findPhotosWithPagination`, `PhotoRepository#findPhotosWithStatistics` are declared with
Oracle-specific native SQL (`TO_CHAR`, `ROWNUM`, `RANK() OVER`) but are never called by any entry point.
They carry no externally observable behavior and are therefore **out of scope** for this spec. Their only
frozen contract is TC-WEB-027: the application context must still start successfully with whatever query
definitions replace them.

## Shared Conventions Used Below

- **Admin credentials** for authenticated requests: HTTP Basic, username `admin`, password
  `test-admin-password` (see `testdata/configuration/upload-validation-settings.md`).
- **Seeding** means inserting the records of the referenced seed file into the `photos` table, loading the
  bytes of each record's `photoDataFile` into the `photo_data` column, before the trigger is issued.
- **Empty table** means the `photos` table contains exactly 0 rows before the trigger is issued.
- **"Database unavailable"** means the datasource the application uses is made to fail every statement for
  the duration of the trigger (connection refused or equivalent). The mechanism is chosen by
  `verify-test-baseline` per `infra-decision-table.md`; the observable contract is what this spec pins.
- **JSON body matching**: see `testdata/expectations/README.md` for placeholder semantics.

---

## Test Cases

### TC-WEB-001 Gallery listing — Happy path

| Field | Value |
|-------|-------|
| ID | TC-WEB-001 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /` |
| Description | The gallery page renders every stored photo, newest upload first, with per-photo links to the detail and binary endpoints. |

**Trigger**

`GET /` with no request body, no `Authorization` header, header `Accept: text/html`.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `200`. Body satisfies every assertion in `testdata/expectations/gallery-page-seeded.md`.

**Resource Verification**

- The `photos` table still contains exactly 3 rows, with primary keys `11111111-1111-1111-1111-111111111111`, `22222222-2222-2222-2222-222222222222`, `33333333-3333-3333-3333-333333333333`.
- The `photo_data`, `file_size`, `width` and `height` column values of all 3 rows are unchanged from the seed.

**Negative Verification**

- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`
- `testdata/expectations/gallery-page-seeded.md`

---

### TC-WEB-002 Gallery listing — Empty collection boundary

| Field | Value |
|-------|-------|
| ID | TC-WEB-002 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `GET /` |
| Description | With zero stored photos the gallery renders the empty-state message and no photo grid. |

**Trigger**

`GET /` with no request body, no `Authorization` header, header `Accept: text/html`.

**Preconditions**

- The `photos` table is empty (0 rows).

**Expected Response**

HTTP `200`. Body satisfies every assertion in `testdata/expectations/gallery-page-empty.md`.

**Resource Verification**

- The `photos` table still contains exactly 0 rows.

**Negative Verification**

- No row is inserted into `photos`.

**Data References**

- `testdata/expectations/gallery-page-empty.md`

---

### TC-WEB-003 Gallery listing — Datastore failure degrades to empty gallery

| Field | Value |
|-------|-------|
| ID | TC-WEB-003 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /` |
| Description | When photo retrieval fails, the gallery page still returns 200 and renders the empty-state message instead of propagating an error. |

**Trigger**

`GET /` with no request body, no `Authorization` header, header `Accept: text/html`, issued while the
database is unavailable.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).
- The database is made unavailable for the duration of the request.

**Expected Response**

HTTP `200`. Body satisfies every assertion in `testdata/expectations/gallery-page-empty.md`.

**Resource Verification**

- After the database is restored, the `photos` table contains exactly the same 3 rows as seeded, with unchanged column values.

**Negative Verification**

- The response status is NOT `500` and NOT `503`.
- The response body does NOT contain the substring `Exception`.
- The response body does NOT contain any element with `id="photo-gallery"`.
- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`
- `testdata/expectations/gallery-page-empty.md`

---

### TC-WEB-004 Gallery listing — Unicode / HTML-significant filenames and NULL dimensions

| Field | Value |
|-------|-------|
| ID | TC-WEB-004 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `GET /` |
| Description | Filenames containing Unicode and HTML-significant characters round-trip through storage and are HTML-escaped on render; records with NULL width/height omit the dimensions text. |

**Trigger**

`GET /` with no request body, no `Authorization` header, header `Accept: text/html`.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed-special-input.json` (2 records).

**Expected Response**

HTTP `200`. Body satisfies every assertion in `testdata/expectations/gallery-page-special-input.md`.

**Resource Verification**

- The `photos` row with primary key `55555555-5555-5555-5555-555555555555` has `original_file_name` byte-equal (UTF-8) to `café-日本語-<script>&"quoted".png`.
- The `photos` row with primary key `66666666-6666-6666-6666-666666666666` has `width` NULL, `height` NULL and `file_path` NULL.

**Negative Verification**

- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed-special-input.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/expectations/gallery-page-special-input.md`

---

### TC-WEB-005 Photo upload — Single JPEG happy path

| Field | Value |
|-------|-------|
| ID | TC-WEB-005 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | An authenticated upload of one valid JPEG stores the binary payload plus metadata and returns the created photo descriptor. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part: name `files`, filename `sample-landscape.jpg`, content type `image/jpeg`, content = bytes of
`testdata/inputs/sample-landscape.jpg` (790 bytes).

**Preconditions**

- The `photos` table is empty (0 rows).

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-success-single-jpeg.json`.

**Resource Verification**

- The `photos` table contains exactly 1 row.
- That row's `id` equals the `uploadedPhotos[0].id` value from the response body.
- That row has `original_file_name` = `sample-landscape.jpg`, `mime_type` = `image/jpeg`, `file_size` = `790`, `width` = `120`, `height` = `80`.
- That row's `stored_file_name` matches `^[0-9a-fA-F-]{36}\.jpg$`, and `file_path` equals `/uploads/` concatenated with `stored_file_name`.
- That row's `photo_data` is byte-identical to `testdata/inputs/sample-landscape.jpg`.
- That row's `uploaded_at` is non-null.

**Negative Verification**

- No file is written under `src/main/resources/static/uploads/` or any other filesystem location by the request; photo bytes exist only in the `photos.photo_data` column.

**Data References**

- `testdata/inputs/sample-landscape.jpg`
- `testdata/expectations/upload-success-single-jpeg.json`
- `testdata/configuration/upload-validation-settings.md`

---

### TC-WEB-006 Photo upload — Multi-file batch across all supported formats

| Field | Value |
|-------|-------|
| ID | TC-WEB-006 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | A batch of three files (JPEG, PNG, GIF) is stored in request order and each descriptor carries the format-specific dimensions. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
Three parts, all named `files`, in this order:
1. filename `sample-landscape.jpg`, content type `image/jpeg`, content = bytes of `testdata/inputs/sample-landscape.jpg` (790 bytes)
2. filename `sample-portrait.png`, content type `image/png`, content = bytes of `testdata/inputs/sample-portrait.png` (233 bytes)
3. filename `sample-square.gif`, content type `image/gif`, content = bytes of `testdata/inputs/sample-square.gif` (92 bytes)

**Preconditions**

- The `photos` table is empty (0 rows).

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-success-three-files.json` (array order is significant and matches part order).

**Resource Verification**

- The `photos` table contains exactly 3 rows.
- The set of `id` values in `photos` equals the set of `uploadedPhotos[*].id` values in the response body.
- The row with `original_file_name` = `sample-landscape.jpg` has `mime_type` = `image/jpeg`, `file_size` = `790`, `width` = `120`, `height` = `80`, and `photo_data` byte-identical to `testdata/inputs/sample-landscape.jpg`.
- The row with `original_file_name` = `sample-portrait.png` has `mime_type` = `image/png`, `file_size` = `233`, `width` = `64`, `height` = `96`, and `photo_data` byte-identical to `testdata/inputs/sample-portrait.png`.
- The row with `original_file_name` = `sample-square.gif` has `mime_type` = `image/gif`, `file_size` = `92`, `width` = `32`, `height` = `32`, and `photo_data` byte-identical to `testdata/inputs/sample-square.gif`.
- All 3 `id` values are distinct, and all 3 `stored_file_name` values are distinct.

**Negative Verification**

- No file is written to the filesystem by the request.

**Data References**

- `testdata/inputs/sample-landscape.jpg`
- `testdata/inputs/sample-portrait.png`
- `testdata/inputs/sample-square.gif`
- `testdata/expectations/upload-success-three-files.json`

---

### TC-WEB-007 Photo upload — Maximum permitted file size boundary

| Field | Value |
|-------|-------|
| ID | TC-WEB-007 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | A payload of exactly the configured maximum size (10485760 bytes) is accepted, and unparseable image bytes yield NULL dimensions rather than a rejection. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part: name `files`, filename `max-size-image.jpg`, content type `image/jpeg`, content = a byte array of
exactly `10485760` bytes, every byte `0x00` (generated at test time; not stored as a fixture).

**Preconditions**

- The `photos` table is empty (0 rows).
- `app.file-upload.max-file-size-bytes` = `10485760` and `spring.servlet.multipart.max-file-size` = `10MB`, per `testdata/configuration/upload-validation-settings.md`.

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-success-max-size-file.json`.

**Resource Verification**

- The `photos` table contains exactly 1 row.
- That row has `file_size` = `10485760`, `mime_type` = `image/jpeg`, `original_file_name` = `max-size-image.jpg`, `width` NULL and `height` NULL.
- That row's `photo_data` has length exactly `10485760` bytes and every byte equals `0x00`.

**Negative Verification**

- The response `failedUploads` array is empty — a payload of exactly the limit is NOT rejected (the rejection rule is strictly greater-than).

**Data References**

- `testdata/expectations/upload-success-max-size-file.json`
- `testdata/configuration/upload-validation-settings.md`

---

### TC-WEB-008 Photo upload — Zero-byte file boundary

| Field | Value |
|-------|-------|
| ID | TC-WEB-008 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | A zero-byte upload is rejected with the empty-file message and nothing is stored. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part: name `files`, filename `empty-file.jpg`, content type `image/jpeg`, content = bytes of
`testdata/inputs/empty-file.jpg` (0 bytes).

**Preconditions**

- The `photos` table is empty (0 rows).

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-failed-empty-file.json`.

**Resource Verification**

- The `photos` table contains exactly 0 rows.

**Negative Verification**

- No row is inserted into `photos`.
- The response `uploadedPhotos` array is empty and the top-level `success` field is `false`.

**Data References**

- `testdata/inputs/empty-file.jpg`
- `testdata/expectations/upload-failed-empty-file.json`

---

### TC-WEB-009 Photo upload — Unicode filename round-trip

| Field | Value |
|-------|-------|
| ID | TC-WEB-009 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | A filename containing Latin-1 accents, CJK characters and a Greek letter is stored and echoed back unchanged as UTF-8. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part: name `files`, filename `café-日本語-Ω.jpg` (UTF-8 encoded in the multipart headers), content type
`image/jpeg`, content = bytes of `testdata/inputs/sample-unicode-name.jpg` (665 bytes).

**Preconditions**

- The `photos` table is empty (0 rows).
- `server.servlet.encoding.charset` = `UTF-8` and `server.servlet.encoding.force` = `true`.

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-success-unicode-filename.json` (the `originalFileName` placeholder escapes
decode to the exact string `café-日本語-Ω.jpg`).

**Resource Verification**

- The `photos` table contains exactly 1 row.
- That row's `original_file_name`, read back and decoded as UTF-8, equals exactly `café-日本語-Ω.jpg` (18 Unicode code points).
- That row has `file_size` = `665`, `mime_type` = `image/jpeg`, `width` = `48`, `height` = `48`.
- That row's `stored_file_name` matches `^[0-9a-fA-F-]{36}\.jpg$` — the generated name contains no non-ASCII characters.
- That row's `photo_data` is byte-identical to `testdata/inputs/sample-unicode-name.jpg`.

**Negative Verification**

- The stored `original_file_name` contains no `?` replacement characters and no `U+FFFD` replacement character.

**Data References**

- `testdata/inputs/sample-unicode-name.jpg`
- `testdata/expectations/upload-success-unicode-filename.json`

---

### TC-WEB-010 Photo upload — Mixed batch, partial success

| Field | Value |
|-------|-------|
| ID | TC-WEB-010 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | A batch containing one valid and one invalid file stores only the valid one and reports both outcomes in a single 200 response. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
Two parts, both named `files`, in this order:
1. filename `sample-landscape.jpg`, content type `image/jpeg`, content = bytes of `testdata/inputs/sample-landscape.jpg` (790 bytes)
2. filename `not-an-image.txt`, content type `text/plain`, content = bytes of `testdata/inputs/not-an-image.txt` (69 bytes)

**Preconditions**

- The `photos` table is empty (0 rows).

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-mixed-one-success-one-failure.json`. Note the top-level `success` field is
`true` because at least one file was stored.

**Resource Verification**

- The `photos` table contains exactly 1 row, with `original_file_name` = `sample-landscape.jpg`, `mime_type` = `image/jpeg`, `file_size` = `790`.
- That row's `photo_data` is byte-identical to `testdata/inputs/sample-landscape.jpg`.

**Negative Verification**

- No row exists in `photos` with `original_file_name` = `not-an-image.txt`.
- No row exists in `photos` with `mime_type` = `text/plain`.

**Data References**

- `testdata/inputs/sample-landscape.jpg`
- `testdata/inputs/not-an-image.txt`
- `testdata/expectations/upload-mixed-one-success-one-failure.json`

---

### TC-WEB-011 Photo upload — Unsupported MIME type rejected

| Field | Value |
|-------|-------|
| ID | TC-WEB-011 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | A file whose declared content type is outside the allow-list is rejected with the unsupported-type message and nothing is stored. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part: name `files`, filename `not-an-image.txt`, content type `text/plain`, content = bytes of
`testdata/inputs/not-an-image.txt` (69 bytes).

**Preconditions**

- The `photos` table is empty (0 rows).
- `app.file-upload.allowed-mime-types` = `image/jpeg,image/png,image/gif,image/webp`.

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-failed-unsupported-mime-type.json`.

**Resource Verification**

- The `photos` table contains exactly 0 rows.

**Negative Verification**

- No row is inserted into `photos`.
- No file is written to the filesystem.
- The response status is NOT `400` and NOT `415` — rejection is reported inside a `200` envelope.

**Data References**

- `testdata/inputs/not-an-image.txt`
- `testdata/expectations/upload-failed-unsupported-mime-type.json`

---

### TC-WEB-012 Photo upload — Unauthenticated request rejected

| Field | Value |
|-------|-------|
| ID | TC-WEB-012 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | Upload is a protected, state-changing operation: without HTTP Basic credentials the request is rejected before any storage interaction. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, **no** `Authorization` header.
One part: name `files`, filename `sample-landscape.jpg`, content type `image/jpeg`, content = bytes of
`testdata/inputs/sample-landscape.jpg` (790 bytes).

**Preconditions**

- The `photos` table is empty (0 rows).

**Expected Response**

HTTP `401`. Response carries a `WWW-Authenticate` header whose value starts with `Basic`. The response body
is not part of the frozen contract.

**Resource Verification**

- The `photos` table contains exactly 0 rows.

**Negative Verification**

- No row is inserted into `photos`.
- The response status is NOT `200` and NOT `302` (no redirect-to-login; the API is stateless HTTP Basic).
- No `Set-Cookie` header is present (stateless session policy).

**Data References**

- `testdata/inputs/sample-landscape.jpg`
- `testdata/configuration/deployment-config-contract.md`

---

### TC-WEB-013 Photo upload — Datastore failure reported per file

| Field | Value |
|-------|-------|
| ID | TC-WEB-013 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | When persistence fails, the upload returns 200 with the file listed in `failedUploads` carrying the persistence-failure message, and no partial row survives. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part: name `files`, filename `sample-landscape.jpg`, content type `image/jpeg`, content = bytes of
`testdata/inputs/sample-landscape.jpg` (790 bytes). Issued while the database is unavailable.

**Preconditions**

- The `photos` table is empty (0 rows).
- The database is made unavailable for the duration of the request.

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-failed-database-unavailable.json`.

**Resource Verification**

- After the database is restored, the `photos` table contains exactly 0 rows.

**Negative Verification**

- No row exists in `photos` with `original_file_name` = `sample-landscape.jpg`.
- The response status is NOT `500`.
- The response `uploadedPhotos` array is empty and the top-level `success` field is `false`.
- No file is written to the filesystem as a fallback.

**Data References**

- `testdata/inputs/sample-landscape.jpg`
- `testdata/expectations/upload-failed-database-unavailable.json`

---

### TC-WEB-014 Photo detail — Happy path with both navigation neighbours

| Field | Value |
|-------|-------|
| ID | TC-WEB-014 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /detail/{id}` |
| Description | The detail page of a middle-aged photo renders its metadata and links to the immediately older and immediately newer photos. |

**Trigger**

`GET /detail/22222222-2222-2222-2222-222222222222`, no request body, no `Authorization` header,
header `Accept: text/html`.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `200`. Body satisfies every assertion in `testdata/expectations/detail-page-bravo.md`.

**Resource Verification**

- The `photos` table still contains exactly 3 rows with unchanged column values.

**Negative Verification**

- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`
- `testdata/expectations/detail-page-bravo.md`

---

### TC-WEB-015 Photo detail — Newest photo has no "next" neighbour

| Field | Value |
|-------|-------|
| ID | TC-WEB-015 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `GET /detail/{id}` |
| Description | At the newest end of the collection the forward navigation link is omitted while the backward link remains. |

**Trigger**

`GET /detail/33333333-3333-3333-3333-333333333333`, no request body, no `Authorization` header,
header `Accept: text/html`.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `200`. Body satisfies every assertion in `testdata/expectations/detail-page-charlie-newest.md`.

**Resource Verification**

- The `photos` table still contains exactly 3 rows with unchanged column values.

**Negative Verification**

- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`
- `testdata/expectations/detail-page-charlie-newest.md`

---

### TC-WEB-016 Photo detail — Unknown and malformed identifiers redirect to the gallery

| Field | Value |
|-------|-------|
| ID | TC-WEB-016 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `GET /detail/{id}` |
| Description | Identifiers that match no stored photo — including a well-formed but absent UUID and a non-UUID string — produce a redirect to the gallery rather than an error page. |

**Trigger**

Two independent requests, each with no request body, no `Authorization` header, `Accept: text/html`:
1. `GET /detail/99999999-9999-9999-9999-999999999999`
2. `GET /detail/not-a-uuid`

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

For each of the two requests: HTTP `302`, response header `Location` ending with `/` (the gallery root).
No response body assertions.

**Resource Verification**

- The `photos` table still contains exactly 3 rows with unchanged column values.

**Negative Verification**

- Neither response has status `200`, `404` or `500`.
- Neither response body contains the substring `Photo Information`.
- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-017 Photo detail — Datastore failure redirects to the gallery

| Field | Value |
|-------|-------|
| ID | TC-WEB-017 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /detail/{id}` |
| Description | A retrieval failure is swallowed and turned into a redirect to the gallery, never a 5xx. |

**Trigger**

`GET /detail/22222222-2222-2222-2222-222222222222`, no request body, no `Authorization` header,
header `Accept: text/html`, issued while the database is unavailable.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).
- The database is made unavailable for the duration of the request.

**Expected Response**

HTTP `302`, response header `Location` ending with `/`. No response body assertions.

**Resource Verification**

- After the database is restored, the `photos` table contains exactly the same 3 rows as seeded, with unchanged column values.

**Negative Verification**

- The response status is NOT `500` and NOT `503`.
- The response body does NOT contain the substring `Exception`.
- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-018 Photo delete — Authenticated delete happy path

| Field | Value |
|-------|-------|
| ID | TC-WEB-018 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `POST /detail/{id}/delete` |
| Description | An authenticated delete removes exactly the targeted photo row, including its binary payload, and redirects to the gallery with a success message. |

**Trigger**

`POST /detail/22222222-2222-2222-2222-222222222222/delete`, HTTP Basic `admin` / `test-admin-password`,
empty request body, no CSRF token.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `302`, response header `Location` ending with `/`. A flash attribute named `successMessage` with the
exact value `Photo deleted successfully` is carried to the redirect target.

**Resource Verification**

- The `photos` table contains exactly 2 rows.
- No row exists in `photos` with `id` = `22222222-2222-2222-2222-222222222222`.
- Rows with `id` = `11111111-1111-1111-1111-111111111111` and `id` = `33333333-3333-3333-3333-333333333333` still exist with unchanged column values, including `photo_data`.
- A subsequent `GET /photo/22222222-2222-2222-2222-222222222222` returns HTTP `404`.

**Negative Verification**

- No flash attribute named `errorMessage` is produced.
- No row other than `22222222-2222-2222-2222-222222222222` is deleted or modified.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-019 Photo delete — Unknown identifier is a no-op

| Field | Value |
|-------|-------|
| ID | TC-WEB-019 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `POST /detail/{id}/delete` |
| Description | Deleting an identifier that matches no stored photo reports "Photo not found" and leaves the collection untouched. |

**Trigger**

`POST /detail/99999999-9999-9999-9999-999999999999/delete`, HTTP Basic `admin` / `test-admin-password`,
empty request body.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `302`, response header `Location` ending with `/`. A flash attribute named `errorMessage` with the
exact value `Photo not found` is carried to the redirect target.

**Resource Verification**

- The `photos` table still contains exactly 3 rows, with primary keys `11111111-1111-1111-1111-111111111111`, `22222222-2222-2222-2222-222222222222`, `33333333-3333-3333-3333-333333333333` and unchanged column values.

**Negative Verification**

- No row is deleted from `photos`.
- No flash attribute named `successMessage` is produced.
- The response status is NOT `404` and NOT `500`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-020 Photo delete — Unauthenticated request rejected

| Field | Value |
|-------|-------|
| ID | TC-WEB-020 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /detail/{id}/delete` |
| Description | Delete is a protected, state-changing operation: without HTTP Basic credentials nothing is removed. |

**Trigger**

`POST /detail/22222222-2222-2222-2222-222222222222/delete`, **no** `Authorization` header, empty request
body.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `401`. Response carries a `WWW-Authenticate` header whose value starts with `Basic`. The response body
is not part of the frozen contract.

**Resource Verification**

- The `photos` table still contains exactly 3 rows with unchanged column values, including the row with `id` = `22222222-2222-2222-2222-222222222222`.

**Negative Verification**

- No row is deleted from `photos`.
- The response status is NOT `302` (no redirect-to-login) and NOT `403`.
- No `Set-Cookie` header is present.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`
- `testdata/configuration/deployment-config-contract.md`

---

### TC-WEB-021 Photo delete — Datastore failure surfaces a retry message

| Field | Value |
|-------|-------|
| ID | TC-WEB-021 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `POST /detail/{id}/delete` |
| Description | A delete failure redirects to the gallery with the retry message rather than propagating a 5xx, and no photo is removed. |

**Trigger**

`POST /detail/22222222-2222-2222-2222-222222222222/delete`, HTTP Basic `admin` / `test-admin-password`,
empty request body, issued while the database is unavailable.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).
- The database is made unavailable for the duration of the request.

**Expected Response**

HTTP `302`, response header `Location` ending with `/`. A flash attribute named `errorMessage` with the
exact value `Failed to delete photo. Please try again.` is carried to the redirect target.

**Resource Verification**

- After the database is restored, the `photos` table contains exactly the same 3 rows as seeded, with unchanged column values.

**Negative Verification**

- No row is deleted from `photos`.
- No flash attribute named `successMessage` is produced.
- The response status is NOT `500` and NOT `503`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-022 Photo binary — Happy path byte-for-byte retrieval

| Field | Value |
|-------|-------|
| ID | TC-WEB-022 |
| Category | happy-path |
| Entry Point Type | HTTP |
| Entry Point | `GET /photo/{id}` |
| Description | The stored binary payload is served unmodified with its stored MIME type, no-cache headers and the diagnostic photo headers. |

**Trigger**

`GET /photo/22222222-2222-2222-2222-222222222222`, no request body, no `Authorization` header.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `200` with:

- `Content-Type` = `image/png`
- `Cache-Control` = `no-cache, no-store, must-revalidate, private`
- `Pragma` = `no-cache`
- `Expires` = `0`
- `X-Photo-ID` = `22222222-2222-2222-2222-222222222222`
- `X-Photo-Name` = `bravo.png`
- `X-Photo-Size` = `229`
- Body byte-identical to `testdata/seed-data/bravo.png` (229 bytes)

**Resource Verification**

- The `photos` table still contains exactly 3 rows with unchanged column values.
- The `photo_data` column of row `22222222-2222-2222-2222-222222222222` is byte-identical to `testdata/seed-data/bravo.png` after the request.

**Negative Verification**

- No row is inserted into, updated in, or deleted from `photos`.
- The response carries no `ETag` and no `Last-Modified` header (caching is explicitly suppressed).

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-023 Photo binary — Smallest stored payload boundary

| Field | Value |
|-------|-------|
| ID | TC-WEB-023 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `GET /photo/{id}` |
| Description | The smallest stored payload (92 bytes, GIF) is served complete and with the correct MIME type, pinning that no minimum-size truncation or padding occurs. |

**Trigger**

`GET /photo/33333333-3333-3333-3333-333333333333`, no request body, no `Authorization` header.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `200` with:

- `Content-Type` = `image/gif`
- `X-Photo-ID` = `33333333-3333-3333-3333-333333333333`
- `X-Photo-Name` = `charlie.gif`
- `X-Photo-Size` = `92`
- `Content-Length` = `92`
- Body byte-identical to `testdata/seed-data/charlie.gif` (92 bytes)

**Resource Verification**

- The `photos` table still contains exactly 3 rows with unchanged column values.

**Negative Verification**

- The response body length is not `0` and not greater than `92`.
- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-024 Photo binary — Metadata row with NULL payload returns 404

| Field | Value |
|-------|-------|
| ID | TC-WEB-024 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `GET /photo/{id}` |
| Description | A photo row whose binary column is NULL is indistinguishable from a missing photo at the boundary: 404, not an empty 200. |

**Trigger**

`GET /photo/44444444-4444-4444-4444-444444444444`, no request body, no `Authorization` header.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed-with-null-photo-data.json` (1 record with `photo_data` NULL).

**Expected Response**

HTTP `404`, empty response body (`Content-Length` = `0` or absent).

**Resource Verification**

- The `photos` table still contains exactly 1 row, with `id` = `44444444-4444-4444-4444-444444444444` and `photo_data` NULL.

**Negative Verification**

- The response status is NOT `200` and NOT `500`.
- The response carries no `X-Photo-ID`, `X-Photo-Name` or `X-Photo-Size` header.
- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed-with-null-photo-data.json`

---

### TC-WEB-025 Photo binary — Unknown identifier returns 404

| Field | Value |
|-------|-------|
| ID | TC-WEB-025 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /photo/{id}` |
| Description | Requesting a photo identifier that matches no stored row returns 404 with no body and no diagnostic headers. |

**Trigger**

`GET /photo/99999999-9999-9999-9999-999999999999`, no request body, no `Authorization` header.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).

**Expected Response**

HTTP `404`, empty response body (`Content-Length` = `0` or absent).

**Resource Verification**

- The `photos` table still contains exactly 3 rows with unchanged column values.

**Negative Verification**

- The response status is NOT `200` and NOT `500`.
- The response carries no `X-Photo-ID`, `X-Photo-Name` or `X-Photo-Size` header.
- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-026 Photo binary — Datastore failure returns 500

| Field | Value |
|-------|-------|
| ID | TC-WEB-026 |
| Category | failure |
| Entry Point Type | HTTP |
| Entry Point | `GET /photo/{id}` |
| Description | Unlike the HTML endpoints, the binary endpoint surfaces a retrieval failure as a 500 with an empty body. |

**Trigger**

`GET /photo/22222222-2222-2222-2222-222222222222`, no request body, no `Authorization` header, issued while
the database is unavailable.

**Preconditions**

- The `photos` table is seeded from `testdata/seed-data/photos-seed.json` (3 records).
- The database is made unavailable for the duration of the request.

**Expected Response**

HTTP `500`, empty response body (`Content-Length` = `0` or absent).

**Resource Verification**

- After the database is restored, the `photos` table contains exactly the same 3 rows as seeded, with unchanged column values.

**Negative Verification**

- The response status is NOT `200` and NOT `404`.
- The response carries no `X-Photo-ID`, `X-Photo-Name` or `X-Photo-Size` header.
- The response body does NOT contain any bytes of `testdata/seed-data/bravo.png`.
- No row is inserted into, updated in, or deleted from `photos`.

**Data References**

- `testdata/seed-data/photos-seed.json`
- `testdata/seed-data/alpha.jpg`
- `testdata/seed-data/bravo.png`
- `testdata/seed-data/charlie.gif`

---

### TC-WEB-027 Application bootstrap — Default port and schema readiness

| Field | Value |
|-------|-------|
| ID | TC-WEB-027 |
| Category | happy-path |
| Entry Point Type | CLI |
| Entry Point | `com.photoalbum.PhotoAlbumApplication#main(String[])` |
| Description | With datasource and admin credentials supplied from the environment and no port override, the application starts, binds HTTP on port 8080, and the `photos` schema is usable. |

**Trigger**

Start the application with an empty `args` array and the following environment:
`SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` (or the equivalent
password-less credential variables for the migrated target) pointing at the test datastore;
`APP_ADMIN_USERNAME=admin`; `APP_ADMIN_PASSWORD=test-admin-password`; **no** `SERVER_PORT` variable set.

**Preconditions**

- The target datastore is reachable and the application user may create and drop tables.

**Expected Response**

The process reaches a started state within 120 seconds. `GET http://localhost:8080/` returns HTTP `200`
and its body satisfies `testdata/expectations/gallery-page-empty.md`.

**Resource Verification**

- A table named `photos` exists in the target schema.
- That table has columns `id`, `original_file_name`, `photo_data`, `stored_file_name`, `file_path`, `file_size`, `mime_type`, `uploaded_at`, `width`, `height`.
- An index named `idx_photos_uploaded_at` exists on the `uploaded_at` column of `photos`.
- Inserting one row via `POST /upload` (authenticated, `testdata/inputs/sample-landscape.jpg`) succeeds with HTTP `200`, proving the schema accepts binary payloads.

**Negative Verification**

- No connection attempt is made to port `1521` on any host (the Oracle listener port is no longer used).
- The startup log contains no line at level `ERROR`.

**Data References**

- `testdata/expectations/gallery-page-empty.md`
- `testdata/inputs/sample-landscape.jpg`
- `testdata/configuration/deployment-config-contract.md`

---

### TC-WEB-028 Application bootstrap — Environment-supplied port override

| Field | Value |
|-------|-------|
| ID | TC-WEB-028 |
| Category | boundary |
| Entry Point Type | CLI |
| Entry Point | `com.photoalbum.PhotoAlbumApplication#main(String[])` |
| Description | The HTTP listen port is taken from the environment, which is what makes the container image portable to a platform-assigned port. |

**Trigger**

Start the application with an empty `args` array, the same datastore and admin environment as TC-WEB-027,
plus `SERVER_PORT=18080`.

**Preconditions**

- The target datastore is reachable.
- TCP port `18080` is free on the test host, and nothing else is listening on port `8080`.

**Expected Response**

The process reaches a started state within 120 seconds. `GET http://localhost:18080/` returns HTTP `200`
and its body satisfies `testdata/expectations/gallery-page-empty.md`.

**Resource Verification**

- The process holds a listening TCP socket on port `18080`.

**Negative Verification**

- The process holds no listening TCP socket on port `8080`.
- A TCP connection attempt to `localhost:8080` is refused.

**Data References**

- `testdata/expectations/gallery-page-empty.md`
- `testdata/configuration/deployment-config-contract.md`

---

### TC-WEB-029 Application bootstrap — Missing datastore credential fails fast

| Field | Value |
|-------|-------|
| ID | TC-WEB-029 |
| Category | failure |
| Entry Point Type | CLI |
| Entry Point | `com.photoalbum.PhotoAlbumApplication#main(String[])` |
| Description | No credential is baked into the image: when neither an explicit datastore password nor a password-less credential mechanism is configured, startup fails instead of silently using a default. |

**Trigger**

Start the application with an empty `args` array, `SPRING_DATASOURCE_URL` and
`SPRING_DATASOURCE_USERNAME` set, `APP_ADMIN_USERNAME=admin`, `APP_ADMIN_PASSWORD=test-admin-password`,
and **no** `SPRING_DATASOURCE_PASSWORD` and **no** password-less credential configuration present.

**Preconditions**

- No `SPRING_DATASOURCE_PASSWORD` environment variable, system property or property-file value is resolvable.
- No password-less (token/identity based) authentication is configured for the datasource.

**Expected Response**

The process terminates with a non-zero exit code within 120 seconds. Startup output contains the text
`spring.datasource.password`.

**Resource Verification**

- `none` — the application never reaches a started state, so it touches no external resource. Verified by the negative checks below.

**Negative Verification**

- No listening TCP socket is opened on port `8080`.
- No table named `photos` is created in the target schema.
- No occurrence of a literal credential value appears in startup output.

**Data References**

- `testdata/configuration/deployment-config-contract.md`

---

### TC-WEB-030 Application bootstrap — No credential literals in packaged configuration

| Field | Value |
|-------|-------|
| ID | TC-WEB-030 |
| Category | special-input |
| Entry Point Type | CLI |
| Entry Point | `com.photoalbum.PhotoAlbumApplication#main(String[])` |
| Description | Every credential consumed at bootstrap is externalized: the packaged configuration contains only unresolved placeholders, never literal secrets. |

**Trigger**

Static inspection of every file under `src/main/resources/` (all property, YAML and profile variants
present in the repository at verification time).

**Preconditions**

- `none` — no application or datastore state is required.

**Expected Response**

`none (static inspection)` — the checks below constitute the assertion set. Each check either passes or the
case fails.

**Resource Verification**

- Every assignment of `spring.datasource.password` under `src/main/resources/` has a value of the exact form `${<NAME>}` with no `:` default segment, or the property is absent entirely.
- Every assignment of `app.admin.password` under `src/main/resources/` has a value of the exact form `${<NAME>}` with no `:` default segment, or the property is absent entirely.
- Every assignment of `spring.datasource.url` and `spring.datasource.username` under `src/main/resources/` is of the form `${<NAME>:<default>}` or `${<NAME>}` — that is, environment-overridable.

**Negative Verification**

- No file under `src/main/resources/` contains the literal string `test-admin-password`.
- No file under `src/main/resources/` contains a `spring.datasource.password=` assignment whose right-hand side is a non-empty literal (anything not starting with `${`).
- No file under `src/main/resources/` contains a `app.admin.password=` assignment whose right-hand side is a non-empty literal (anything not starting with `${`).

**Data References**

- `testdata/configuration/deployment-config-contract.md`

---

### TC-WEB-031 Photo upload — Missing `files` part rejected with 400

| Field | Value |
|-------|-------|
| ID | TC-WEB-031 |
| Category | boundary |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | A multipart request that carries no `files` part at all is rejected at the request-binding boundary with 400 and never reaches storage. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part named `unrelated` with content type `text/plain` and content `ignored`; **no** part named `files`.

**Preconditions**

- The `photos` table is empty (0 rows).

**Expected Response**

HTTP `400`. Body satisfies every assertion in `testdata/expectations/upload-error-missing-files-part.md`.

**Resource Verification**

- The `photos` table contains exactly 0 rows.

**Negative Verification**

- No row is inserted into `photos`.
- The response status is NOT `200`.

**Data References**

- `testdata/expectations/upload-error-missing-files-part.md`

---

### TC-WEB-032 Photo upload — Decompression-bomb dimensions rejected

| Field | Value |
|-------|-------|
| ID | TC-WEB-032 |
| Category | special-input |
| Entry Point Type | HTTP |
| Entry Point | `POST /upload` |
| Description | An image whose declared pixel count exceeds 40 000 000 is rejected on dimensions alone, before the payload is stored. |

**Trigger**

`POST /upload`, `Content-Type: multipart/form-data`, HTTP Basic `admin` / `test-admin-password`.
One part: name `files`, filename `pixel-bomb-10000x5000.jpg`, content type `image/jpeg`, content = bytes of
`testdata/inputs/pixel-bomb-10000x5000.jpg` (293721 bytes, declared dimensions 10000 × 5000 = 50 000 000 pixels).

**Preconditions**

- The `photos` table is empty (0 rows).
- The maximum decoded image size is `40000000` pixels, per `testdata/configuration/upload-validation-settings.md`.

**Expected Response**

HTTP `200`, `Content-Type: application/json`. Body matches
`testdata/expectations/upload-failed-pixel-bomb.json`.

**Resource Verification**

- The `photos` table contains exactly 0 rows.

**Negative Verification**

- No row is inserted into `photos`.
- No row exists in `photos` with `original_file_name` = `pixel-bomb-10000x5000.jpg`.
- The response `uploadedPhotos` array is empty and the top-level `success` field is `false`.

**Data References**

- `testdata/inputs/pixel-bomb-10000x5000.jpg`
- `testdata/expectations/upload-failed-pixel-bomb.json`
- `testdata/configuration/upload-validation-settings.md`

---

## Required Field Checklist (Freeze Gate)

- [x] **ID** unique, formatted `TC-<MODULE>-<NNN>` — TC-WEB-001 … TC-WEB-032, all distinct.
- [x] **Category** is one of `happy-path`, `boundary`, `special-input`, `failure` in every case.
- [x] **Entry Point Type** is `HTTP` or `CLI` throughout; the same mechanism always uses the same label.
- [x] **Entry Point** is an exact production identifier (HTTP method+path, or FQ `main` method).
- [x] **Trigger** enumerates method, path, headers, auth, and every multipart part with its exact byte source.
- [x] **Preconditions** enumerated (or `none`); every referenced seed file exists under `testdata/seed-data/`.
- [x] **Expected Response** specifies exact status, headers and body source in every case.
- [x] **Resource Verification** has at least one bullet in every case; TC-WEB-029 uses `none` with justification.
- [x] **Negative Verification** present for all `failure` cases (TC-WEB-003, 011, 012, 013, 017, 020, 021, 025, 026, 029) and all no-op cases (TC-WEB-008, 016, 019, 024, 031, 032).
- [x] **Data References** complete; all paths verified to exist under `testdata/`.

## Coverage Gate

- [x] Every entry point appears as the `Entry Point` of at least one `happy-path` case: `GET /` → TC-WEB-001; `POST /upload` → TC-WEB-005, TC-WEB-006; `GET /detail/{id}` → TC-WEB-014; `POST /detail/{id}/delete` → TC-WEB-018; `GET /photo/{id}` → TC-WEB-022; `main` → TC-WEB-027 (plus existing `PhotoAlbumApplicationTests#contextLoads`).
- [x] Every entry point appears as the `Entry Point` of at least one `failure` case: `GET /` → TC-WEB-003; `POST /upload` → TC-WEB-011, TC-WEB-012, TC-WEB-013; `GET /detail/{id}` → TC-WEB-017; `POST /detail/{id}/delete` → TC-WEB-020, TC-WEB-021; `GET /photo/{id}` → TC-WEB-025, TC-WEB-026; `main` → TC-WEB-029.
- [x] All four buckets covered per entry point: `GET /` (001/002/004/003), `POST /upload` (005+006/007+008+031/009+010+032/011+012+013), `GET /detail/{id}` (014/015/016/017), `POST /detail/{id}/delete` (018/—/019/020+021 — no size or pagination boundary exists for a single-key delete, so the `boundary` bucket is not applicable), `GET /photo/{id}` (022/023/024/025+026), `main` (027/028/030/029).
- [x] Entity examples use 3 representative records in the primary seed, 1 in the NULL-payload seed and 2 in the special-input seed — within the 2–5 range for the primary dataset.

# Upload Validation Settings (frozen)

The values below are the configuration the upload test cases in `test-cases.md` assume. They must be
applied to the application under test (any profile / property source is acceptable).

| Property | Value |
|---|---|
| `app.file-upload.max-file-size-bytes` | `10485760` |
| `app.file-upload.allowed-mime-types` | `image/jpeg,image/png,image/gif,image/webp` |
| `app.file-upload.max-files-per-upload` | `10` |
| `spring.servlet.multipart.max-file-size` | `10MB` |
| `spring.servlet.multipart.max-request-size` | `50MB` |
| `server.servlet.encoding.charset` | `UTF-8` |
| `server.servlet.encoding.force` | `true` |
| `app.admin.username` | `admin` |
| `app.admin.password` | `test-admin-password` (test-only value, matches `src/test/resources/application-test.properties`) |

Derived constants pinned by the spec:

| Constant | Value | Source |
|---|---|---|
| Maximum decoded image pixels | `40000000` | `PhotoServiceImpl.MAX_IMAGE_PIXELS` |
| Rejection message — unsupported type | `File type not supported. Please upload JPEG, PNG, GIF, or WebP images.` | `PhotoServiceImpl#uploadPhoto` |
| Rejection message — oversized | `File size exceeds 10MB limit.` | `PhotoServiceImpl#uploadPhoto` (`String.format("File size exceeds %dMB limit.", 10485760 / 1024 / 1024)`) |
| Rejection message — empty | `File is empty.` | `PhotoServiceImpl#uploadPhoto` |
| Rejection message — pixel bomb | `Image dimensions exceed the allowed limit.` | `PhotoServiceImpl#uploadPhoto` |
| Rejection message — persistence failure | `Error saving photo to database. Please try again.` | `PhotoServiceImpl#uploadPhoto` |

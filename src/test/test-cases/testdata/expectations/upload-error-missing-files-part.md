# Expected response — `POST /upload` with the `files` part omitted

| # | Assertion |
|---|---|
| 1 | HTTP status is `400` |
| 2 | Response `Content-Type` starts with `application/json` |
| 3 | Parsed JSON body contains the key `status` with value `400` |
| 4 | Parsed JSON body does NOT contain the key `uploadedPhotos` |
| 5 | Parsed JSON body does NOT contain the key `failedUploads` |

The body is produced by the framework's default error handler, so only the assertions above are pinned;
no other field of the error body is part of the frozen contract.

# Expected DOM — `GET /detail/22222222-2222-2222-2222-222222222222` with `testdata/seed-data/photos-seed.json` seeded

`bravo.png` is the middle record by `uploaded_at`, so both navigation links must be present.

| # | Assertion |
|---|---|
| 1 | `<title>` text equals `bravo.png - Photo Album` |
| 2 | Exactly one element matches `img.photo-detail-image`, and its `src` equals `/photo/22222222-2222-2222-2222-222222222222` |
| 3 | That image's `alt` equals `bravo.png` |
| 4 | Exactly one `form` has `action` equal to `/detail/22222222-2222-2222-2222-222222222222/delete` and `method` equal to `post` |
| 5 | An anchor exists with `href` equal to `/detail/11111111-1111-1111-1111-111111111111` and link text containing `Previous Photo` |
| 6 | An anchor exists with `href` equal to `/detail/33333333-3333-3333-3333-333333333333` and link text containing `Next Photo` |
| 7 | The document contains the exact text `bravo.png` in the `Filename:` definition-list entry |
| 8 | The document contains the exact text `64 x 96 px` |
| 9 | The document contains the exact text `image/png` |
| 10 | The document contains the exact text `229 bytes` |
| 11 | The document does NOT contain the text `Photo not found` |
| 12 | HTTP response `Content-Type` starts with `text/html` and declares `charset=UTF-8` |

Navigation semantics pinned by assertions 5 and 6: "Previous" is the newest photo **older** than the current
one; "Next" is the oldest photo **newer** than the current one.

# Expected DOM — `GET /detail/33333333-3333-3333-3333-333333333333` (newest photo) with `testdata/seed-data/photos-seed.json` seeded

`charlie.gif` is the newest record by `uploaded_at`, so the "Next Photo" link must be absent.

| # | Assertion |
|---|---|
| 1 | `<title>` text equals `charlie.gif - Photo Album` |
| 2 | Exactly one element matches `img.photo-detail-image`, and its `src` equals `/photo/33333333-3333-3333-3333-333333333333` |
| 3 | An anchor exists with `href` equal to `/detail/22222222-2222-2222-2222-222222222222` and link text containing `Previous Photo` |
| 4 | No anchor in the document has link text containing `Next Photo` |
| 5 | The document contains the exact text `32 x 32 px` |
| 6 | The document contains the exact text `image/gif` |
| 7 | HTTP response `Content-Type` starts with `text/html` and declares `charset=UTF-8` |

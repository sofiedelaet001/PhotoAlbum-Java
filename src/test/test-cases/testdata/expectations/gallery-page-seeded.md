# Expected DOM — `GET /` with `testdata/seed-data/photos-seed.json` seeded

Assertions are made against the parsed HTML document, not against a byte-for-byte golden file.

| # | Assertion |
|---|---|
| 1 | `<title>` text equals `Photo Gallery - Photo Album` |
| 2 | Exactly one element with `id="photo-gallery"` exists |
| 3 | No element with `id="photo-gallery"` sibling alert containing the text `No photos yet. Upload your first photo to get started!` |
| 4 | `#photo-gallery` contains exactly 3 elements matching `div.card.photo-card` |
| 5 | The `img` elements inside `#photo-gallery`, in document order, have `src` attributes exactly: `/photo/33333333-3333-3333-3333-333333333333`, `/photo/22222222-2222-2222-2222-222222222222`, `/photo/11111111-1111-1111-1111-111111111111` |
| 6 | The `img` elements inside `#photo-gallery`, in document order, have `alt` attributes exactly: `charlie.gif`, `bravo.png`, `alpha.jpg` |
| 7 | Each card contains an anchor whose `href` equals `/detail/<id>` for the same id as its image |
| 8 | The rendered document contains the exact substrings `32 x 32`, `64 x 96` and `120 x 80` (one per card) |
| 9 | HTTP response `Content-Type` starts with `text/html` and declares `charset=UTF-8` |

Ordering rule pinned by assertions 5 and 6: photos are listed by `uploaded_at` **descending** (newest first).

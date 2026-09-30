# Expected DOM — `GET /` with an empty `photos` table

| # | Assertion |
|---|---|
| 1 | `<title>` text equals `Photo Gallery - Photo Album` |
| 2 | No element with `id="photo-gallery"` exists in the document |
| 3 | The document contains the exact text `No photos yet. Upload your first photo to get started!` |
| 4 | Exactly 0 elements match `div.card.photo-card` |
| 5 | The document contains an element with `id="upload-form"` |
| 6 | HTTP response `Content-Type` starts with `text/html` and declares `charset=UTF-8` |

This is also the expected DOM when photo retrieval fails (see the failure test case): `HomeController#index`
catches the exception and renders the same page with an empty photo list.

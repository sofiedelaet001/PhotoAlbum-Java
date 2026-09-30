# Expected DOM — `GET /` with `testdata/seed-data/photos-seed-special-input.json` seeded

| # | Assertion |
|---|---|
| 1 | HTTP status is `200` |
| 2 | `#photo-gallery` contains exactly 2 elements matching `div.card.photo-card` |
| 3 | The `img` elements inside `#photo-gallery`, in document order, have `src` attributes exactly: `/photo/66666666-6666-6666-6666-666666666666`, `/photo/55555555-5555-5555-5555-555555555555` |
| 4 | After HTML parsing, the `alt` attribute of the second image (document order) equals the exact string `café-日本語-<script>&"quoted".png` |
| 5 | The **raw** response body does NOT contain the substring `<script>&"quoted"` (the filename is HTML-escaped, not injected as markup) |
| 6 | The raw response body contains the substring `&lt;script&gt;` |
| 7 | The parsed document contains no `script` element whose text or attributes derive from a photo filename; the only `script` elements are the two at the end of the body (`bootstrap.bundle.min.js` and `/js/upload.js`) |
| 8 | For the card whose image `src` is `/photo/66666666-6666-6666-6666-666666666666`, the card body contains the text `1 KB` and contains no text matching the pattern `\d+ x \d+` (dimensions span omitted when width/height are NULL) |
| 9 | Response `Content-Type` starts with `text/html` and declares `charset=UTF-8`; decoding the body as UTF-8 reproduces assertion 4 exactly |

## 2024-10-26 - Prevent HTTP Request Indefinite Hanging
**Learning:** Dart's `http` package doesn't enforce a default timeout for HTTP requests. This can lead to indefinite hanging if the server is unresponsive, potentially causing resource exhaustion or UI freezes if not awaited properly.
**Action:** Always append `.timeout(Duration(seconds: X))` to `http.get`, `http.post`, etc., calls when making network requests to external APIs.
## 2024-05-15 - [ReDoS Vulnerability in Bible Reference Regex]
**Vulnerability:** Regular Expression Denial of Service (ReDoS) in `GetBibleAPI._parseReference`.
**Learning:** The overlapping character classes `[... \s]+?` followed by `\s+` allowed catastrophic backtracking when parsing malformed spaces or long texts.
**Prevention:** Avoid overlapping characters sets, and match alternating sequences instead, e.g., `[a-z]+(?:\s+[a-z]+)*`.
## 2024-10-26 - Add Input Length Limits
**Vulnerability:** Unbounded inputs in `TextField` widgets could lead to a Denial of Service (DoS) vulnerability via memory exhaustion if a user pasted extremely large strings.
**Learning:** Adding `maxLength` enforces reasonable limits at the UI level.
**Prevention:** Always add `maxLength` limits to user-facing inputs like `TextField` widgets when appropriate.
## 2024-10-30 - Fix URL Injection and Unhandled String Slicing
**Vulnerability:** Application crashed with `RangeError` when slicing a `lang` parameter of length < 2, leading to localized DoS. Additionally, `bibleId`, `bookNr`, and `chapter` variables were not properly URL-encoded during API URL construction in `getPassage`, creating an SSRF / Path Traversal vulnerability (URL Injection).
**Learning:** String indices must always be checked before slicing to prevent unhandled runtime errors. Any user-influenced parameters appended to URLs must be URL-encoded.
**Prevention:** Use `lang.length >= 2` prior to substring operations. Always apply `Uri.encodeComponent` on any URL variables constructed dynamically.

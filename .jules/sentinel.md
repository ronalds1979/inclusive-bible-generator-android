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
## 2024-11-04 - Fix Path Traversal and RangeError DoS Vulnerabilities
**Vulnerability:** The `backgroundFilename` parameter in `generateImageBytes` was directly interpolated into a `rootBundle.load` path without sanitization, leading to a Path Traversal vulnerability. Additionally, `startIdx` and `endIdx` boundaries were not validated before calling `List.sublist` in `getPassage`, creating a RangeError DoS vulnerability if malformed or swapped indices were provided.
**Learning:** External inputs mapped to file paths or list indices must always be validated and sanitized. In Flutter, failing to handle `RangeError` from array slicing can cause unhandled exceptions that disrupt the app flow.
**Prevention:** Sanitize filenames with `.split('/').last.split('\\').last` before loading them from assets or the file system. Always check index boundaries explicitly (e.g., `if (endIdx < startIdx) return null;`) prior to performing substring or sublist operations.

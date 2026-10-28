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

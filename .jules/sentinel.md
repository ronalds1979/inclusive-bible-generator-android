## 2024-10-26 - Prevent HTTP Request Indefinite Hanging
**Learning:** Dart's `http` package doesn't enforce a default timeout for HTTP requests. This can lead to indefinite hanging if the server is unresponsive, potentially causing resource exhaustion or UI freezes if not awaited properly.
**Action:** Always append `.timeout(Duration(seconds: X))` to `http.get`, `http.post`, etc., calls when making network requests to external APIs.

## 2024-05-18 - Adding API Timeout
**Vulnerability:** Missing timeout configuration for HTTP requests to `api.getbible.net`.
**Learning:** External API dependencies without timeouts can cause the application to hang indefinitely and introduce resource exhaustion / Denial of Service (DoS) risks. Also learned that exception details in server-side logs shouldn't be hidden by generic messages - user-facing errors should be sanitized, but logs should retain stack traces for debugging.
**Prevention:** Always append a `.timeout()` (e.g., `const Duration(seconds: 10)`) to `http.get` requests in Dart/Flutter.

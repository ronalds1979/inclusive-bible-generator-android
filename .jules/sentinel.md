## 2024-05-24 - [Information Leakage in Production via print()]
**Vulnerability:** Raw `print("Error ...: $e")` statements were used for error handling across the app. In Flutter, `print()` writes to standard output, which is logged to the device console (Logcat/syslog) even in production release builds.
**Learning:** This exposes internal errors, stack traces, and potentially sensitive details (like API request formatting failures or file paths) to any user or app with log access, creating an information disclosure vulnerability.
**Prevention:** Use `debugPrint` wrapped in `if (kDebugMode)` for all logging to ensure error details are only exposed during development.

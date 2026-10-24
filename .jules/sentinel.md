## 2024-05-19 - Avoid printing exception details to console in production
 **Learning:** `print()` or `debugPrint()` without `if (kDebugMode)` can leak sensitive exception details into production logs.
 **Action:** Always wrap exception logging with `if (kDebugMode)` when using `debugPrint` in Dart/Flutter apps.

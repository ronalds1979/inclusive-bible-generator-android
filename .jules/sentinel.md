## 2024-05-18 - Missing Network Timeouts

 **Learning:** External API requests in the `getbible_api.dart` service were missing explicit timeouts. Without timeouts, the app can hang indefinitely if the network is unresponsive or the server drops connections without closing them, leading to a denial of service (DoS) for the user.
 **Action:** Always enforce timeouts (e.g., `.timeout(const Duration(seconds: 10))`) on all external network requests using the `http` package to ensure the application remains responsive and fails gracefully on network errors.

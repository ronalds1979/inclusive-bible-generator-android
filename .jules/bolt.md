## 2024-10-26 - Asynchronous File I/O Optimization
**Learning:** Using synchronous file I/O operations (`existsSync`, `readAsBytesSync`) in asynchronous contexts blocks the Dart main event loop, causing severe UI jank, especially for large files.
**Action:** Always prefer asynchronous file I/O equivalents (`exists`, `readAsBytes`) with `await` within `async` functions to keep the event loop non-blocking and UI responsive.

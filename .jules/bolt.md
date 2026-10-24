## 2024-10-24 - Async Loading Operations
**Learning:** Sequential `await` calls in a `for` loop for loading local asset files (such as locales with `rootBundle.loadString`) cause unnecessary execution delay, as each file load blocks the next one.
**Action:** Use `Future.wait` combined with an `Iterable.map` to load resources concurrently, especially for relatively low-cost I/O operations like loading small JSON locales, to optimize load times and reduce app startup latency.

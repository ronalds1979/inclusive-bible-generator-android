
## 2024-10-26 - [Avoid Redundant Method Calls in Loops]
**Learning:** Calling methods like `.toLowerCase()` on invariant variables inside a tight loop results in unnecessary string allocations and computation overhead, leading to performance degradation. In Flutter/Dart, optimizing string operations in parsing layers is crucial.
**Action:** Always pre-compute invariant values before looping (e.g., caching `string.toLowerCase()`) when the value is compared repeatedly against dictionary/mapping entries.
## 2024-05-18 - Optimized String Formatting in Generator
**Learning:** Using `replaceAll` inside a `.forEach` loop over `kwargs` creates multiple intermediate strings, leading to performance bottlenecks during template formatting.
**Action:** Always prefer pre-compiling a static `RegExp` and using `replaceAllMapped` in Dart to perform multi-key string replacements in a single pass without unnecessary allocations.

## 2024-10-28 - [Fast-path optimization for String replacements before Map Lookups]
**Learning:** Performing expensive string normalizations (e.g., multiple `.replaceAll()` calls) before dictionary/map lookups creates unnecessary allocations when the provided string is already correctly normalized (e.g., passing "en" instead of "English (US/UK)"). This is especially problematic in hot paths like localization lookups during UI rebuilds.
**Action:** Implement a "fast-path" pattern: check if the map `containsKey()` the raw input first. Only run the expensive normalization logic and fallback if the initial check fails.

## 2024-11-20 - [Avoid Synchronous File I/O in Async Contexts]
**Learning:** Using synchronous file I/O operations (like `existsSync` and `readAsBytesSync`) inside an asynchronous function blocks the Dart main event loop and can cause UI jank, especially when reading large custom background images.
**Action:** Always prefer asynchronous file I/O equivalents (`await exists()`, `await readAsBytes()`) within async methods in Flutter to keep the main thread free.

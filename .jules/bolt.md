
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
## 2024-05-24 - Avoid O(N) lowercase lookup loops
**Learning:** Checking for an exact dictionary match first (O(1) fast-path) can skip O(N) iterative `toLowerCase()` evaluations for well-formatted user inputs.
**Action:** Always verify if a map exact lookup `containsKey()` can be used as a fast-path before performing iterative string normalizations in fallback loops.

## 2024-05-18 - Offload Heavy Image Processing
**Learning:** Performing heavy operations such as image decoding, scaling, drawing, and encoding on the main thread in Flutter blocks the event loop and can cause severe UI jank, especially for large assets or images.
**Action:** Use `compute()` from `package:flutter/foundation.dart` to offload these heavy synchronous tasks (like `img.decodeImage`, `img.encodePng` from the `image` package) to a background isolate.

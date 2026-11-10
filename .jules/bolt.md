
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

## 2025-02-12 - [Avoid Repetitive String Operations in Widget Build Methods]
**Learning:** Performing multiple expensive string operations (like `.toLowerCase().contains()`) directly inline within a Flutter `build()` method creates redundant computations and object allocations every time the widget rebuilds. This is especially problematic in forms where `setState` runs frequently (e.g., on every keystroke).
**Action:** Extract repetitive string computations into cached local variables at the top of the `build()` method, or wrap the specific UI component in a `Builder` widget to cache the values locally and prevent redundant operations across the widget tree.
## 2024-05-20 - Prevent Full-Page Rebuilds
**Learning:** Rebuilding the entire page via setState inside onChanged for TextFields is a major performance bottleneck in Flutter forms.
**Action:** Use ValueListenableBuilder for single controllers (like conditional suffix icons) and AnimatedBuilder with Listenable.merge for dependent UI components (like live previews) to localize rebuilds to only the necessary widgets.

## 2025-02-13 - [Pre-compile RegExp and Cache Listenable.merge]
**Learning:** Re-instantiating `RegExp` patterns inside methods called frequently and passing inline `Listenable.merge` inside `build` blocks in Flutter (which instantiates a new listener proxy each time) causes unnecessary object allocations and GC churn, affecting runtime performance.
**Action:** Extract `RegExp` patterns to `static final` fields so they compile only once. Cache dynamic Listeners (like `Listenable.merge`) inside a `State`'s `initState` to reuse the instance during widget rebuilds.

## 2024-05-24 - [Avoid `img.compositeImage` for simple static overlays]
**Learning:** Using `img.compositeImage` for simple static color overlays (like a 50% opacity black mask) creates unnecessary memory allocations and CPU overhead because it computes full alpha blending on a new image instance.
**Action:** Instead of allocating a new image and computing alpha blending, manually iterate over the original image pixels and perform simple arithmetic (e.g., divide the RGB values by 2 for a 50% black mask) to save memory and CPU cycles.

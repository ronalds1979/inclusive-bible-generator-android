
## 2024-10-26 - [Avoid Redundant Method Calls in Loops]
**Learning:** Calling methods like `.toLowerCase()` on invariant variables inside a tight loop results in unnecessary string allocations and computation overhead, leading to performance degradation. In Flutter/Dart, optimizing string operations in parsing layers is crucial.
**Action:** Always pre-compute invariant values before looping (e.g., caching `string.toLowerCase()`) when the value is compared repeatedly against dictionary/mapping entries.
## 2024-05-18 - Optimized String Formatting in Generator
**Learning:** Using `replaceAll` inside a `.forEach` loop over `kwargs` creates multiple intermediate strings, leading to performance bottlenecks during template formatting.
**Action:** Always prefer pre-compiling a static `RegExp` and using `replaceAllMapped` in Dart to perform multi-key string replacements in a single pass without unnecessary allocations.

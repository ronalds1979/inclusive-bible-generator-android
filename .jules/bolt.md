
## 2024-10-26 - [Avoid Redundant Method Calls in Loops]
**Learning:** Calling methods like `.toLowerCase()` on invariant variables inside a tight loop results in unnecessary string allocations and computation overhead, leading to performance degradation. In Flutter/Dart, optimizing string operations in parsing layers is crucial.
**Action:** Always pre-compute invariant values before looping (e.g., caching `string.toLowerCase()`) when the value is compared repeatedly against dictionary/mapping entries.

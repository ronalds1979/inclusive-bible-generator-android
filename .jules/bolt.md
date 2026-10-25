## 2026-10-25 - Expensive string manipulations in setState
**Learning:** Per-keystroke `setState` calls can rapidly trigger code, making seemingly minor string manipulations (like 4 successive `replaceAll`s on locale keys) quite expensive. These add up, especially if standard components aren't memoizing.
**Action:** Add fast paths/early returns for common string normalization functions (like standard locale string mapping) so it bypasses replacements entirely on cache hits, avoiding unnecessary regex processing.

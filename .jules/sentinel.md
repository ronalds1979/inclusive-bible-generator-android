## 2024-10-26 - Prevent HTTP Request Indefinite Hanging
**Learning:** Dart's `http` package doesn't enforce a default timeout for HTTP requests. This can lead to indefinite hanging if the server is unresponsive, potentially causing resource exhaustion or UI freezes if not awaited properly.
**Action:** Always append `.timeout(Duration(seconds: X))` to `http.get`, `http.post`, etc., calls when making network requests to external APIs.
## 2024-05-15 - [ReDoS Vulnerability in Bible Reference Regex]
**Vulnerability:** Regular Expression Denial of Service (ReDoS) in `GetBibleAPI._parseReference`.
**Learning:** The overlapping character classes `[... \s]+?` followed by `\s+` allowed catastrophic backtracking when parsing malformed spaces or long texts.
**Prevention:** Avoid overlapping characters sets, and match alternating sequences instead, e.g., `[a-z]+(?:\s+[a-z]+)*`.
## 2024-10-26 - Add Input Length Limits
**Vulnerability:** Unbounded inputs in `TextField` widgets could lead to a Denial of Service (DoS) vulnerability via memory exhaustion if a user pasted extremely large strings.
**Learning:** Adding `maxLength` enforces reasonable limits at the UI level.
**Prevention:** Always add `maxLength` limits to user-facing inputs like `TextField` widgets when appropriate.
## 2024-10-30 - Fix URL Injection and Unhandled String Slicing
**Vulnerability:** Application crashed with `RangeError` when slicing a `lang` parameter of length < 2, leading to localized DoS. Additionally, `bibleId`, `bookNr`, and `chapter` variables were not properly URL-encoded during API URL construction in `getPassage`, creating an SSRF / Path Traversal vulnerability (URL Injection).
**Learning:** String indices must always be checked before slicing to prevent unhandled runtime errors. Any user-influenced parameters appended to URLs must be URL-encoded.
**Prevention:** Use `lang.length >= 2` prior to substring operations. Always apply `Uri.encodeComponent` on any URL variables constructed dynamically.
## 2024-11-05 - Fix RangeError DoS in Sublist Operations
**Vulnerability:** A Denial of Service (DoS) vulnerability existed in `GetBibleAPI.getPassage` where `verses.sublist(startIdx, endIndex)` was called without explicitly verifying that `endIndex >= startIdx`. If a user provided an invalid range where the start index was greater than the end index, it would throw an unhandled `RangeError`, potentially crashing the application or the background isolate.
**Learning:** Dart's `List.sublist` and string slicing methods will throw runtime exceptions if index boundaries are invalid or crossed.
**Prevention:** Always explicitly validate that `endIndex >= startIndex` before performing list or string slicing operations to ensure the application fails securely and gracefully.
## 2024-11-08 - Prevent Path Traversal in Flutter Asset Loading
**Vulnerability:** Path traversal vulnerability in `Generator.generateImageBytes` due to unsanitized `backgroundFilename` being passed to `rootBundle.load`.
**Learning:** Loading assets via `rootBundle.load` with dynamically constructed paths without input validation allows path traversal.
**Prevention:** Sanitize filenames (e.g., `.split('/').last.split('\\').last`) before using them to construct asset paths for `rootBundle.load`.
## 2024-11-10 - Prevent Memory Exhaustion via Unbounded File Reads
**Vulnerability:** A Denial of Service (DoS) vulnerability existed in `Generator.generateImageBytes` where `File.readAsBytes()` was called on user-selected custom images without a size limit, which could cause memory exhaustion if excessively large files were provided.
**Learning:** Reading unbounded local files entirely into memory using `readAsBytes` can cause application crashes (OOM) and DoS on devices with constrained memory.
**Prevention:** Always check `await File(path).length()` against a reasonable limit (e.g., 20MB) before calling `readAsBytes()`.

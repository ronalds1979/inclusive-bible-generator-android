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
## 2024-11-12 - Prevent Memory Exhaustion via Unbounded File Reads in UI
**Vulnerability:** A Denial of Service (DoS) vulnerability existed in `_selectCustomImage` where user-selected custom images were loaded into memory via `FileImage` without validating their size, potentially leading to Out-Of-Memory (OOM) crashes if a user selected an excessively large file.
**Learning:** File size validation must occur immediately at the UI layer when files are selected, before passing file paths to frontend rendering components like `FileImage` which will attempt to decode the entire file into memory.
**Prevention:** Always check `await File(path).length()` against a reasonable limit (e.g., 20MB) upon file selection and before initiating file rendering or processing in the UI.


## 2026-11-17 - Comprehensive Security Hardening (Sentinel Audit Remediation)
**Vulnerabilities Remediated:**
- Disabled automatic HTTP redirect following in `StockPhotoService` (`followRedirects = false`) with per-hop allowlist validation (`parseAllowedWikimediaUri`) up to 3 hops, bounded API responses, and JPEG/PNG magic-byte verification before saving downloads.
- Added consistent API key validation (`GeminiService.normalizeApiKey`) across `loadApiKey()`, `saveApiKey()`, `GeminiAuthDialog`, and `main.dart`.
- Cleared in-memory key caches (`_zeroQuotaImageKeys` and `_youVersionBiblesCache`) inside `saveApiKey()` and `saveYouVersionApiKey()`, and bounded cache sizes to 16 entries.
- Bounded HTTP response payloads (20 MB in `GeminiService`, 2 MB in `GetBibleAPI`), hardened base64 decoding against `FormatException` and oversized payloads, sanitized prompt inputs (`_sanitizePromptField`), and stripped raw HTML/exception details from `lastError`.
- Disabled runtime Google Fonts fetching (`GoogleFonts.config.allowRuntimeFetching = false`), moved transient export/background PNGs to `getTemporaryDirectory()` with startup pruning, and updated locale paste instructions.
- Removed redundant `READ_EXTERNAL_STORAGE` permission from `AndroidManifest.xml`, enabled `filterTouchesWhenObscured = true` in `MainActivity.kt`, pinned `distributionSha256Sum` in `gradle-wrapper.properties`, and added `.env*`/`*.jks`/`*.keystore`/`key.properties` to `.gitignore`.

## 2026-11-17 - Follow-up Audit Hardening
**Vulnerabilities Remediated:**
- Added `GetBibleAPI.normalizeYouVersionApiKey` validation across `loadYouVersionApiKey`, `saveYouVersionApiKey`, `detectYouVersionKeyFromClipboard`, `YouVersionAuthDialog`, and `main.dart` to reject malformed header tokens.
- Added early reference length caps (`<= 100` chars) in `GetBibleAPI._parseReference` and replaced buffered HTTP requests in `GetBibleAPI` and `GeminiService` with streamed bounded helpers (`_getBoundedResponse`, `_postBounded`) that disable automatic redirects (`followRedirects = false`) and enforce `maxResponseBytes` during chunk streaming.
- Added `GeminiService.isValidRasterImageBytes` (PNG/JPEG/WebP magic-byte verification) for gallery background picks and Gemini responses in `main.dart`.
- Fixed relative `storeFile` resolution in `android/app/build.gradle.kts` (`rootProject.file` fallback) and added `android/key.properties.example` documenting env-var release signing.

## 2026-11-17 - Input Bounds, Service-Level Key Normalization & Dialog Hardening
**Vulnerabilities Remediated:**
- Added `îûÎÛ` accent parity to `GetBibleAPI._referenceRegExp`, enforced `_bibleIdRegExp` and chapter/verse bounds (`1..150` and `1..200`), and normalized `youVersionApiKey` across all `GetBibleAPI` entrypoints (`getVersions`, `fetchYouVersionBibles`, `getPassage`, `getVerseOfTheDay`).
- Hardened `StockPhotoService.parseAllowedWikimediaUri` to reject embedded `userInfo` and non-443 ports, and stripped control characters / capped queries at 100 chars in `searchPhotos()` and `StockPhotoSearchCard`.
- Disabled keyboard suggestions and autocorrect (`enableSuggestions: false`, `autocorrect: false`) on API key `TextField`s in `GeminiAuthDialog` and `YouVersionAuthDialog`.
- Bounded book search input (`maxLength: 100`), hardened `_loadPreferredBibleVersions()` (64 KB size limit and allowed-language/length filtering), and sanitized asset background names in `VersePreviewCard` and `main.dart`.

## 2026-11-20 - Dart Stream.timeout() Per-Chunk vs Total Stream Deadline
**Vulnerability:** `StockPhotoService` used `stream.timeout(duration)` inside `await for`, which resets on every incoming chunk and allows a slow-drip response to hold connections open indefinitely.
**Learning:** Unlike `Future.timeout()` around the entire stream collection loop, Dart's `Stream.timeout()` only enforces an inter-chunk idle timeout.
**Prevention:** Always wrap the full stream-reading loop in an async helper and apply `.timeout(deadline)` to the resulting `Future`, as done in `_readBoundedBytes`.

## 2026-11-24 - Unbounded Height in Flutter Image Decoders (Pixel-Bomb OOM DoS)
**Vulnerability:** `ContrastSampler.sampleImageBytes` (`targetWidth: 48` with `targetHeight: null`), `VersePreviewCard` (`ResizeImage.resizeIfNeeded(1080, null, ...)`), and `_selectCustomImage` checked file bytes (<= 20 MB) and magic headers but did not inspect image dimensions or bound both decode axes, allowing a tiny `1 x 100,000` PNG to decode up to `48 x 4,800,000` pixels (~921 MB RGBA).
**Learning:** Leaving either `targetHeight` or `height` as `null` in `ui.instantiateImageCodec` or `ResizeImage` scales the unconstrained axis proportionally, magnifying extreme aspect-ratio inputs into OOM crashes even when byte size is tiny.
**Prevention:** Inspect encoded dimensions via `ui.ImageDescriptor.encoded` (`isSafeImageDimensions`) before decoding, and always bound both axes (`targetWidth`+`targetHeight` or `ResizeImagePolicy.fit`).


## 2026-11-28 - Unbounded Bitmap Decode & Media Size in Native VerseVideoMuxer
**Vulnerability:** `VerseVideoMuxer` (`VerseVideoMuxer.kt`) called `BitmapFactory.decodeFile` with `inPreferredConfig = ARGB_8888` and no `inSampleSize`, dimension/pixel caps, or file-size bounds on the input image and WAV audio files.
**Learning:** Bounding image dimensions only at the Dart picker/preview layer leaves native Kotlin `MethodChannel` helpers exposed to pixel-bomb and oversized-media OOM crashes when invoked directly or with large exported buffers.
**Prevention:** Enforce explicit `MAX_IMAGE_BYTES`, `MAX_AUDIO_BYTES`, `MAX_IMAGE_DIMENSION`, `MAX_IMAGE_PIXELS`, and `inSampleSize` downsampling in `VerseVideoMuxer` before allocating native `Bitmap` or AAC sample buffers.

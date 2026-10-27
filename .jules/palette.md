## 2024-05-18 - Added Loading States to Async Buttons

**Learning:** Missing loading indicators for async operations (fetching verses, generating content) in this app causes confusion, as the user might click the buttons multiple times.

**Action:** Add visual loading feedback to buttons (like `CircularProgressIndicator` instead of text, and disable the button while loading) for all operations that involve networking or heavy local processing.

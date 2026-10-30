## 2024-05-18 - Added Loading States to Async Buttons

**Learning:** Missing loading indicators for async operations (fetching verses, generating content) in this app causes confusion, as the user might click the buttons multiple times.

**Action:** Add visual loading feedback to buttons (like `CircularProgressIndicator` instead of text, and disable the button while loading) for all operations that involve networking or heavy local processing.

## 2026-10-28 - Dynamic Color Contrast for Color Pickers
**Learning:** Hardcoding text colors (like black) on dynamic colored backgrounds (like a color picker button) causes severe WCAG contrast violations when dark colors are selected.
**Action:** Use `.computeLuminance()` on the selected color to dynamically switch between black and white text, ensuring accessible contrast ratios regardless of user selection.

## 2024-05-24 - [Accessible Status Messages]
**Learning:** In Flutter, dynamically updated text elements (like status or error messages) aren't automatically announced by screen readers, and hardcoded colors (like `Colors.green`) for all statuses (including errors) create severe cognitive and visual accessibility barriers.
**Action:** Wrap dynamic status text in `Semantics(liveRegion: true)` for screen reader announcements, and dynamically assign context-aware theme colors (e.g., `Theme.of(context).colorScheme.error` for errors) to ensure WCAG color contrast compliance and logical feedback.
## 2024-05-13 - Clear Inputs on TextFields
**Learning:** For forms where users might paste or input long blocks of text (like verses), manual deletion is tedious and error-prone. Providing a "clear" suffix icon button dramatically improves the flow for corrections or new inputs.
**Action:** Always consider adding `suffixIcon` clear buttons to `TextField` widgets that handle multi-line or long content to improve keyboard efficiency and accessibility for screen readers.

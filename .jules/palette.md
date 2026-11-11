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

## 2024-05-24 - Checkbox Accessibility & Tap Targets
**Learning:** In Flutter, the default `Checkbox` widget has a very small tap target (just the icon itself), which makes it difficult for users to interact with, especially on mobile devices or for those with motor impairments.
**Action:** When using a `Checkbox` next to a label (`Text`), wrap both inside an `InkWell` (and a `Row`) to massively expand the touch target, ensuring the entire label area can be tapped to toggle the checkbox.

## 2024-05-24 - Dynamic Loading States for `ElevatedButton.icon`
**Learning:** When using `ElevatedButton.icon`, completely replacing the button's content with a `CircularProgressIndicator` during async loading removes the label text, causing the button's width to violently collapse (layout jank) and creating a disorienting UX.
**Action:** When implementing loading states on `ElevatedButton.icon`, maintain the `label` text consistently, and conditionally swap only the `icon` parameter with a `SizedBox` (matching the icon size, e.g., 16x16) containing the `CircularProgressIndicator`.

## 2024-05-24 - Dynamic Disabled States to Prevent "Dead Clicks"
**Learning:** In forms where required data is missing (e.g., empty text fields or unselected dropdowns), leaving action buttons enabled results in "dead clicks"—where the user clicks and either nothing happens, or an unhelpful error is shown. This breaks the flow and increases user frustration.
**Action:** Always dynamically disable primary action buttons (like submit, fetch, or generate) when required input fields are empty or invalid, providing immediate visual feedback on the state of the form.

## 2026-11-07 - Dynamic Contrast in ElevatedButtons
**Learning:** When styling an `ElevatedButton.icon` with a dynamic `backgroundColor`, applying dynamic contrast logic (like `computeLuminance() > 0.5 ? Colors.black : Colors.white`) directly to the `foregroundColor` inside `ElevatedButton.styleFrom()` ensures both the icon and the text remain accessible and readable. Hardcoding the text color directly on the `Text` widget fails to update the `Icon` color to match.
**Action:** Use `foregroundColor` within `ElevatedButton.styleFrom()` for consistent and accessible styling across both icons and text when the button has a dynamic or user-selected background color.
## 2024-11-09 - Fix dead button states for forms
**Learning:** Primary action buttons that depend on text inputs (like form fields) often appear in a "dead" disabled state when implemented directly in a stateless-like context, such as a large `build` method where text field typing doesn't trigger state rebuilds.
**Action:** Always wrap buttons that depend on dynamic input lengths in reactive builders (`ValueListenableBuilder` or `AnimatedBuilder` for multiple controllers) to ensure they instantly enable/disable and provide immediate, accurate visual feedback to the user.
## 2024-05-18 - Fix Multiline TextField Label Alignment
**Learning:** By default in Flutter, `TextField` labels are vertically centered. For multiline text fields (`maxLines` > 1), this causes the label to float awkwardly in the middle of the input area. Setting `alignLabelWithHint: true` forces the label to align with the top of the input.
**Action:** Always set `alignLabelWithHint: true` on `InputDecoration` when using multiline `TextField`s to ensure a proper visual hierarchy and a standard user experience.

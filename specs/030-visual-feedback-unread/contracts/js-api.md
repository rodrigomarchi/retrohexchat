# JavaScript API Contracts: Visual Feedback & Unread Indicators

## `unread.js` — Unread Badge Rendering Logic

Pure functions for creating and updating unread badge elements in the treebar.

### Constants

```javascript
export const MAX_DISPLAY_COUNT = 99;
export const BADGE_CLASS = "treebar-badge";
export const BADGE_HIGHLIGHT_CLASS = "treebar-badge--highlight";
```

### Functions

#### `formatCount(count)`

Format an unread count for display.

- **Input**: `count: number` — raw unread count.
- **Output**: `string` — `""` if 0, `"99+"` if > 99, else `"${count}"`.

#### `createBadgeElement(count, isHighlight)`

Create a badge DOM element.

- **Input**: `count: number`, `isHighlight: boolean`.
- **Output**: `HTMLElement` — a `<span>` with class `treebar-badge` (and `treebar-badge--highlight` if mention).

#### `updateBadge(listItem, count, isHighlight)`

Update or remove the badge on a treebar list item.

- **Input**: `listItem: HTMLElement`, `count: number`, `isHighlight: boolean`.
- **Effect**: If count > 0, adds/updates badge span. If count === 0, removes badge. If isHighlight, adds red dot class.

#### `clearBadge(listItem)`

Remove the badge from a treebar list item.

- **Input**: `listItem: HTMLElement`.
- **Effect**: Removes `.treebar-badge` child if present.

## `feedback_toast.js` — Copy/Settings Toast Logic

Pure functions for triggering feedback toasts via the existing Z2 toast infrastructure.

### Functions

#### `showFeedbackToast(hookEl, message, duration)`

Create and show a simple feedback toast (no checkbox, no suppress logic).

- **Input**: `hookEl: HTMLElement` — the toast container element, `message: string`, `duration: number` (ms).
- **Effect**: Creates a simpler toast element (just message + close button), animates in, auto-dismisses after `duration`.

#### `createFeedbackToastElement(message)`

Create the DOM element for a feedback toast.

- **Input**: `message: string`.
- **Output**: `HTMLElement` — a retro window with title "Info", body text, and no checkbox.

## TreebarHook Modifications

### New Event Handlers

#### `handleEvent("channel_joined_flash", {channel})`

Applies green flash animation to the specified treebar channel entry.

- Finds the `<li>` element for the channel.
- Adds class `tree-join-flash`.
- Removes class after 1000ms via `setTimeout`.

#### `handleEvent("feedback_toast", {message, duration})`

Delegates to `showFeedbackToast` from `feedback_toast.js`.

### Badge Rendering

The treebar hook does NOT render badges — badges are rendered server-side in the HEEx template. The hook only handles:
- Join flash animation (client-side CSS class toggle)

## ScrollHook Modifications

### Copy Toast Trigger

After `navigator.clipboard.writeText(text)` succeeds in the `clipboard_copy` and `clipboard_copy_selection` handlers:

```javascript
// After successful clipboard write:
this.pushEvent("feedback_toast_trigger", { message: "Copiado!", duration: 2000 });
```

Alternatively, the copy toast can be triggered purely client-side by directly invoking `showFeedbackToast` on the toast container element, avoiding a server round-trip for a purely cosmetic notification.

**Decision**: Client-side trigger preferred — the copy event is already handled in JS, and a round-trip to the server just to show a toast is wasteful.

## Hook Lifecycle

```text
TreebarHook.mounted()
├── Register "channel_joined_flash" handler
└── Register "feedback_toast" handler (for settings toast from server)

ScrollHook.mounted() (existing)
├── Register "clipboard_copy" handler
│   └── After clipboard.writeText → trigger feedback toast client-side
└── Register "clipboard_copy_selection" handler
    └── After clipboard.writeText → trigger feedback toast client-side
```

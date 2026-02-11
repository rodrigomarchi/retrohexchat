# Contract: JavaScript Hooks for Formatting

**Files**: `assets/js/hooks/format_hook.js`, `assets/js/hooks/format_toolbar_hook.js`
**Purpose**: Handle keyboard shortcuts and toolbar interactions for inserting mIRC format codes.

## FormatHook

Attached to the `#chat-input` element (alongside existing CommandPaletteHook).

### Keyboard Event Handling

| Shortcut | Action                        | Control Code |
|----------|-------------------------------|--------------|
| Ctrl+B   | Insert bold toggle            | 0x02 (\x02) |
| Ctrl+I   | Insert italic toggle          | 0x1D (\x1D) |
| Ctrl+U   | Insert underline toggle       | 0x1F (\x1F) |
| Ctrl+K   | Insert color code             | 0x03 (\x03) |
| Ctrl+R   | Insert reverse toggle         | 0x16 (\x16) |
| Ctrl+O   | Insert reset                  | 0x0F (\x0F) |

### Behavior

- Listens for `keydown` events on the input element
- On matching Ctrl+key: `preventDefault()`, insert control character at `selectionStart`, advance cursor by 1
- Does NOT interfere with other shortcuts (Ctrl+C, Ctrl+V, Ctrl+A, etc.)
- Does NOT interfere with CommandPaletteHook events (Tab, ArrowUp/Down, Escape)

### Input Mutation

```javascript
// Pseudocode for character insertion
function insertAtCursor(input, char) {
  const start = input.selectionStart;
  const end = input.selectionEnd;
  const value = input.value;
  input.value = value.slice(0, start) + char + value.slice(end);
  input.selectionStart = input.selectionEnd = start + char.length;
  // Dispatch input event so LiveView tracks the value
  input.dispatchEvent(new Event("input", { bubbles: true }));
}
```

## FormatToolbarHook

Attached to the formatting toolbar container element.

### Button Handling

- Listens for `mousedown` (not `click`) on buttons with `data-format-code` attribute
- On mousedown: `preventDefault()` (prevents input blur), insert the code character into `#chat-input` at cursor position
- Color picker: toggle visibility of dropdown on Color button mousedown; on swatch mousedown, insert `\x03` + color number

### Color Picker Dropdown

- Toggled by mousedown on the Color button
- Dismissed by: clicking outside (document mousedown listener), pressing Escape, or selecting a color
- Positioned absolutely below the Color button
- Contains 16 swatch elements in a 4x4 grid, each with `data-color-code="N"`

### Focus Management

- Input focus is never lost during toolbar interaction (mousedown + preventDefault)
- Cursor position in input is preserved and advanced after insertion

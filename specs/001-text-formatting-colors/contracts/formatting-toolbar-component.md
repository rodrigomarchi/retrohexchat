# Contract: FormattingToolbar Component

**Module**: `RetroHexChatWeb.Components.FormattingToolbar`
**File**: `apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/formatting_toolbar.ex`
**Purpose**: Render a retro-style formatting toolbar above the chat input.

## Component Interface

### `formatting_toolbar(assigns) :: Phoenix.LiveView.Rendered.t()`

Function component. No required assigns. Purely presentational — all interaction handled by `FormatToolbarHook` JS hook.

### Rendered HTML Structure

```html
<div class="formatting-toolbar" id="formatting-toolbar" phx-hook="FormatToolbarHook">
  <button type="button" class="format-btn" data-format-code="\x02"
          data-testid="fmt-bold" title="Bold (Ctrl+B)">
    <strong>B</strong>
  </button>
  <button type="button" class="format-btn" data-format-code="\x1D"
          data-testid="fmt-italic" title="Italic (Ctrl+I)">
    <em>I</em>
  </button>
  <button type="button" class="format-btn" data-format-code="\x1F"
          data-testid="fmt-underline" title="Underline (Ctrl+U)">
    <u>U</u>
  </button>
  <div class="format-color-picker-wrapper">
    <button type="button" class="format-btn format-color-btn"
            data-testid="fmt-color" title="Text Color (Ctrl+K)">
      A
    </button>
    <div class="format-color-dropdown" hidden>
      <!-- 4x4 grid of 16 color swatches -->
      <button type="button" class="color-swatch" data-color-code="0"
              style="background-color: #FFFFFF" title="White (0)"></button>
      <!-- ... 1 through 15 ... -->
      <button type="button" class="color-swatch" data-color-code="15"
              style="background-color: #D2D2D2" title="Light Grey (15)"></button>
    </div>
  </div>
</div>
```

### CSS Classes

| Class                        | Purpose                                        |
|------------------------------|-------------------------------------------------|
| `.formatting-toolbar`        | Container, flex row, retro raised panel style  |
| `.format-btn`                | Individual button, retro button style, 20x20px |
| `.format-color-btn`          | Color button with colored underline indicator   |
| `.format-color-picker-wrapper` | Relative-positioned wrapper for dropdown      |
| `.format-color-dropdown`     | Absolute-positioned 4x4 grid, retro sunken panel |
| `.color-swatch`              | 16x16px color square, retro button style       |

### Placement

Rendered in ChatLive template between the chat messages area and the input form:

```
┌─────────────────────────────────┐
│ Chat Messages (scrollable)      │
├─────────────────────────────────┤
│ [B] [I] [U] [Color▾]           │  ← FormattingToolbar
├─────────────────────────────────┤
│ [Input box...              Send]│
└─────────────────────────────────┘
```

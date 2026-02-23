defmodule RetroHexChatWeb.Components.FormattingToolbar do
  @moduledoc """
  Formatting toolbar with Bold, Italic, Underline buttons and a 4x4 color picker dropdown.
  Uses mousedown (not click) to avoid stealing focus from the chat input.
  """
  use Phoenix.Component

  @color_palette [
    {"White", "#ffffff"},
    {"Black", "#000000"},
    {"Navy", "#00007f"},
    {"Green", "#009300"},
    {"Red", "#ff0000"},
    {"Brown", "#7f0000"},
    {"Purple", "#9c009c"},
    {"Orange", "#fc7f00"},
    {"Yellow", "#ffff00"},
    {"Light Green", "#00fc00"},
    {"Teal", "#009393"},
    {"Light Cyan", "#00ffff"},
    {"Blue", "#0000fc"},
    {"Pink", "#ff00ff"},
    {"Grey", "#7f7f7f"},
    {"Light Grey", "#d2d2d2"}
  ]

  attr :strip_formatting, :boolean, default: false

  @spec formatting_toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def formatting_toolbar(assigns) do
    assigns = assign(assigns, :color_palette, @color_palette)

    ~H"""
    <div class="formatting-toolbar" id="formatting-toolbar" phx-hook="FormatToolbarHook">
      <button
        type="button"
        class="format-btn"
        data-format-code="bold"
        data-testid="format-btn-bold"
        title="Bold (Ctrl+Shift+B)"
      >
        <svg viewBox="0 0 14 14" fill="currentColor">
          <path d="M3 1h5a3 3 0 0 1 2.1 5.1A3.5 3.5 0 0 1 8.5 13H3V1zm2 5h3a1 1 0 1 0 0-2H5v2zm0 2v3h3.5a1.5 1.5 0 0 0 0-3H5z" />
        </svg>
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="italic"
        data-testid="format-btn-italic"
        title="Italic (Ctrl+Shift+Y)"
      >
        <svg viewBox="0 0 14 14" fill="currentColor">
          <path d="M5 1h6v2H9.2L7.3 11H9v2H3v-2h1.8L6.7 3H5V1z" />
        </svg>
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="underline"
        data-testid="format-btn-underline"
        title="Underline (Ctrl+Shift+U)"
      >
        <svg viewBox="0 0 14 14" fill="currentColor">
          <path d="M3 1v5.5a4 4 0 0 0 8 0V1h-2v5.5a2 2 0 0 1-4 0V1H3zm-1 11h10v2H2v-2z" />
        </svg>
      </button>
      <div class="format-color-picker-wrapper">
        <button
          type="button"
          class="format-btn"
          data-format-code="color"
          data-testid="format-btn-color"
          title="Color (Ctrl+Shift+D)"
        >
          <svg viewBox="0 0 14 14" fill="currentColor">
            <rect x="1" y="1" width="4" height="4" fill="#ff0000" />
            <rect x="5" y="1" width="4" height="4" fill="#00ff00" />
            <rect x="9" y="1" width="4" height="4" fill="#0000ff" />
            <rect x="1" y="5" width="4" height="4" fill="#ffff00" />
            <rect x="5" y="5" width="4" height="4" fill="#ff00ff" />
            <rect x="9" y="5" width="4" height="4" fill="#00ffff" />
            <rect x="1" y="9" width="12" height="4" fill="#555" />
          </svg>
        </button>
        <div class="format-color-dropdown">
          <button
            :for={{{name, hex}, i} <- Enum.with_index(@color_palette)}
            type="button"
            class="color-swatch"
            data-color-code={to_string(i)}
            style={"background-color: #{hex};"}
            title={name}
          >
          </button>
        </div>
      </div>
      <button
        type="button"
        class="format-btn"
        data-format-code="reverse"
        data-testid="format-btn-reverse"
        title="Reverse (Ctrl+Shift+V)"
      >
        <svg viewBox="0 0 14 14" fill="currentColor">
          <rect x="1" y="1" width="6" height="12" fill="#000" />
          <rect x="7" y="1" width="6" height="12" fill="#fff" stroke="#555" stroke-width="0.5" />
          <text
            x="4"
            y="10.5"
            text-anchor="middle"
            font-size="8"
            font-weight="bold"
            font-family="sans-serif"
            fill="#fff"
          >
            R
          </text>
          <text
            x="10"
            y="10.5"
            text-anchor="middle"
            font-size="8"
            font-weight="bold"
            font-family="sans-serif"
            fill="#000"
          >
            R
          </text>
        </svg>
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="reset"
        data-testid="format-btn-reset"
        title="Reset (Ctrl+Shift+X)"
      >
        <svg viewBox="0 0 14 14" fill="currentColor">
          <text
            x="7"
            y="10"
            text-anchor="middle"
            font-size="9"
            font-weight="bold"
            font-family="sans-serif"
            fill="#555"
          >
            Aa
          </text>
          <line x1="2" y1="2" x2="12" y2="12" stroke="#FF0000" stroke-width="2" />
        </svg>
      </button>
      <span class="format-separator"></span>
      <button
        type="button"
        class={"format-btn #{if @strip_formatting, do: "format-btn-active"}"}
        phx-click="toggle_strip_formatting"
        data-testid="strip-formatting-toggle"
        title="Strip Colors"
      >
        <svg viewBox="0 0 14 14" fill="currentColor">
          <circle cx="7" cy="7" r="6" fill="none" stroke="currentColor" stroke-width="1.5" />
          <line x1="3" y1="11" x2="11" y2="3" stroke="currentColor" stroke-width="1.5" />
        </svg>
      </button>
      <span class="format-separator"></span>
      <button
        type="button"
        class="format-btn"
        phx-click="toggle_emoji_picker"
        data-emoji-toggle="true"
        data-testid="emoji-picker-toggle"
        title="Emoji Picker"
      >
        <svg viewBox="0 0 14 14" fill="currentColor">
          <circle cx="7" cy="7" r="6" fill="none" stroke="currentColor" stroke-width="1.5" />
          <circle cx="5" cy="5.5" r="0.8" />
          <circle cx="9" cy="5.5" r="0.8" />
          <path d="M4.5 8.5 Q7 11 9.5 8.5" fill="none" stroke="currentColor" stroke-width="1" />
        </svg>
      </button>
    </div>
    """
  end
end

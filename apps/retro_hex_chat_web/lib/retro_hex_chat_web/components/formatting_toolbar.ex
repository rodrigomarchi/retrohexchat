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
        title="Bold (Ctrl+B)"
      >
        <strong>B</strong>
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="italic"
        data-testid="format-btn-italic"
        title="Italic (Ctrl+I)"
      >
        <em>I</em>
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="underline"
        data-testid="format-btn-underline"
        title="Underline (Ctrl+U)"
      >
        <u>U</u>
      </button>
      <div class="format-color-picker-wrapper">
        <button
          type="button"
          class="format-btn format-btn-color"
          data-format-code="color"
          data-testid="format-btn-color"
          title="Color (Ctrl+K)"
        >
          C
        </button>
        <div class="format-color-dropdown" style="display: none;">
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
      <span class="format-separator"></span>
      <button
        type="button"
        class={"format-btn format-btn-strip #{if @strip_formatting, do: "format-btn-active"}"}
        phx-click="toggle_strip_formatting"
        data-testid="strip-formatting-toggle"
        title="Strip Colors"
      >
        S
      </button>
    </div>
    """
  end
end

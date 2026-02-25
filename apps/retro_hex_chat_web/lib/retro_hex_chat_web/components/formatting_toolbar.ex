defmodule RetroHexChatWeb.Components.FormattingToolbar do
  @moduledoc """
  Formatting toolbar with Bold, Italic, Underline buttons and a 4x4 color picker dropdown.
  Uses mousedown (not click) to avoid stealing focus from the chat input.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  @color_names ~w(White Black Navy Green Red Brown Purple Orange Yellow) ++
                 ["Light Green", "Teal", "Light Cyan", "Blue", "Pink", "Grey", "Light Grey"]

  attr :strip_formatting, :boolean, default: false

  @spec formatting_toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def formatting_toolbar(assigns) do
    assigns = assign(assigns, :color_names, @color_names)

    ~H"""
    <div class="formatting-toolbar" id="formatting-toolbar" phx-hook="FormatToolbarHook">
      <button
        type="button"
        class="format-btn"
        data-format-code="bold"
        data-testid="format-btn-bold"
        title="Bold (Ctrl+Shift+B)"
      >
        <Icons.icon_fmt_bold />
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="italic"
        data-testid="format-btn-italic"
        title="Italic (Ctrl+Shift+Y)"
      >
        <Icons.icon_fmt_italic />
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="underline"
        data-testid="format-btn-underline"
        title="Underline (Ctrl+Shift+U)"
      >
        <Icons.icon_fmt_underline />
      </button>
      <div class="format-color-picker-wrapper">
        <button
          type="button"
          class="format-btn"
          data-format-code="color"
          data-testid="format-btn-color"
          title="Color (Ctrl+Shift+D)"
        >
          <Icons.icon_fmt_color />
        </button>
        <div class="format-color-dropdown">
          <button
            :for={{name, i} <- Enum.with_index(@color_names)}
            type="button"
            class={"color-swatch irc-bg-#{i}"}
            data-color-code={to_string(i)}
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
        <Icons.icon_fmt_reverse />
      </button>
      <button
        type="button"
        class="format-btn"
        data-format-code="reset"
        data-testid="format-btn-reset"
        title="Reset (Ctrl+Shift+X)"
      >
        <Icons.icon_fmt_reset />
      </button>
      <span class="format-separator"></span>
      <button
        type="button"
        class={"format-btn #{if @strip_formatting, do: "format-btn-active"}"}
        phx-click="toggle_strip_formatting"
        data-testid="strip-formatting-toggle"
        title="Strip Colors"
      >
        <Icons.icon_fmt_strip />
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
        <Icons.icon_fmt_emoji />
      </button>
    </div>
    """
  end
end

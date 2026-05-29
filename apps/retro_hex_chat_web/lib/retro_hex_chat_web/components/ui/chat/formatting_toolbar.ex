defmodule RetroHexChatWeb.Components.UI.FormattingToolbar do
  @moduledoc """
  Formatting toolbar component for the showcase design system.

  Composed from toolbar primitives. Hook-compatible with FormatToolbarHook:
  uses `.format-btn` class and string `data-format-code` names.
  Color dropdown uses `.format-color-dropdown` and `data-format-color-swatch` elements.

  ## Usage

      <.formatting_toolbar
        id="my-toolbar"
        on_format="format-text"
        on_toggle_emoji="toggle-emoji"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar

  alias RetroHexChatWeb.Icons

  @color_names ~w(White Black Navy Green Red Brown Purple Orange Yellow) ++
                 ["Light Green", "Teal", "Light Cyan", "Blue", "Pink", "Grey", "Light Grey"]

  @doc "Renders the formatting toolbar."
  attr :id, :string, default: "formatting-toolbar"
  attr :bold_active, :boolean, default: false
  attr :italic_active, :boolean, default: false
  attr :underline_active, :boolean, default: false
  attr :strip_active, :boolean, default: false
  attr :on_format, :any, default: nil, doc: "Format button callback (receives phx-value-format)"
  attr :on_toggle_emoji, :any, default: nil, doc: "Emoji picker toggle callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec formatting_toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def formatting_toolbar(assigns) do
    assigns = assign(assigns, :color_names, @color_names)

    ~H"""
    <div
      class={classes(["space-y-retro-2 hidden md:block", @class])}
      phx-hook="FormatToolbarHook"
      id={@id}
      {@rest}
    >
      <.toolbar variant="compact">
        <%!-- Text formatting buttons --%>
        <.toolbar_button
          variant="compact"
          label="Bold (Ctrl+Shift+B)"
          active={@bold_active}
          class="format-btn"
          data-format-code="bold"
          data-testid="format-btn-bold"
        >
          <Icons.icon_fmt_bold class="w-3.5 h-3.5" />
        </.toolbar_button>
        <.toolbar_button
          variant="compact"
          label="Italic (Ctrl+Shift+Y)"
          active={@italic_active}
          class="format-btn"
          data-format-code="italic"
          data-testid="format-btn-italic"
        >
          <Icons.icon_fmt_italic class="w-3.5 h-3.5" />
        </.toolbar_button>
        <.toolbar_button
          variant="compact"
          label="Underline (Ctrl+Shift+U)"
          active={@underline_active}
          class="format-btn"
          data-format-code="underline"
          data-testid="format-btn-underline"
        >
          <Icons.icon_fmt_underline class="w-3.5 h-3.5" />
        </.toolbar_button>

        <.toolbar_separator variant="compact" />

        <%!-- Color picker toggle + dropdown --%>
        <div class="format-color-picker-wrapper relative inline-flex items-center">
          <.toolbar_button
            variant="compact"
            label="Color (Ctrl+Shift+D)"
            class="format-btn"
            data-format-code="color"
            data-testid="format-btn-color"
          >
            <Icons.icon_fmt_color class="w-3.5 h-3.5" />
          </.toolbar_button>
          <div class="format-color-dropdown">
            <button
              :for={{name, i} <- Enum.with_index(@color_names)}
              type="button"
              class={"w-4 h-4 border border-[#0a0a0a] shadow-retro-field cursor-pointer irc-bg-#{i}"}
              data-color-code={to_string(i)}
              data-format-color-swatch
              data-testid={"format-color-swatch-#{i}"}
              title={name}
            >
            </button>
          </div>
        </div>

        <.toolbar_separator variant="compact" />

        <%!-- Control buttons --%>
        <.toolbar_button
          variant="compact"
          label="Reverse (Ctrl+Shift+V)"
          class="format-btn"
          data-format-code="reverse"
          data-testid="format-btn-reverse"
        >
          <Icons.icon_fmt_reverse class="w-3.5 h-3.5" />
        </.toolbar_button>
        <.toolbar_button
          variant="compact"
          label="Reset (Ctrl+Shift+X)"
          class="format-btn"
          data-format-code="reset"
          data-testid="format-btn-reset"
        >
          <Icons.icon_fmt_reset class="w-3.5 h-3.5" />
        </.toolbar_button>

        <.toolbar_separator variant="compact" />

        <%!-- Strip formatting --%>
        <.toolbar_button
          variant="compact"
          label="Strip Colors"
          active={@strip_active}
          phx-click={@on_format}
          phx-value-format="strip"
          data-testid="strip-formatting-toggle"
        >
          <Icons.icon_fmt_strip class="w-3.5 h-3.5" />
        </.toolbar_button>

        <.toolbar_separator variant="compact" />

        <%!-- Emoji toggle --%>
        <.toolbar_button
          variant="compact"
          label="Emoji Picker"
          phx-click={@on_toggle_emoji}
          data-emoji-toggle="true"
          data-testid="emoji-picker-toggle"
        >
          <Icons.icon_fmt_emoji class="w-3.5 h-3.5" />
        </.toolbar_button>
      </.toolbar>
    </div>
    """
  end
end

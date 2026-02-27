defmodule RetroHexChatWeb.Components.UI.FormattingToolbar do
  @moduledoc """
  Formatting toolbar component for the showcase design system.

  Composed from toolbar + color_picker primitives.
  Provides B/I/U buttons, color picker, Reverse/Reset/Strip, and emoji toggle.

  ## Usage

      <.formatting_toolbar />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Toolbar
  import RetroHexChatWeb.Components.UI.ColorPicker

  alias RetroHexChatWeb.Icons

  @doc "Renders the formatting toolbar."
  attr :show_color_picker, :boolean, default: false
  attr :selected_color, :integer, default: nil
  attr :bold_active, :boolean, default: false
  attr :italic_active, :boolean, default: false
  attr :underline_active, :boolean, default: false
  attr :class, :string, default: nil
  attr :rest, :global

  @spec formatting_toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def formatting_toolbar(assigns) do
    ~H"""
    <div class={classes(["space-y-retro-2", @class])} {@rest}>
      <.toolbar>
        <%!-- Text formatting buttons --%>
        <.toolbar_button label="Bold" active={@bold_active}>
          <Icons.icon_fmt_bold class="w-3.5 h-3.5" />
        </.toolbar_button>
        <.toolbar_button label="Italic" active={@italic_active}>
          <Icons.icon_fmt_italic class="w-3.5 h-3.5" />
        </.toolbar_button>
        <.toolbar_button label="Underline" active={@underline_active}>
          <Icons.icon_fmt_underline class="w-3.5 h-3.5" />
        </.toolbar_button>

        <.toolbar_separator />

        <%!-- Color picker toggle --%>
        <.toolbar_button label="Color">
          <Icons.icon_fmt_color class="w-3.5 h-3.5" />
        </.toolbar_button>

        <.toolbar_separator />

        <%!-- Control buttons --%>
        <.toolbar_button label="Reverse">
          <Icons.icon_fmt_reverse class="w-3.5 h-3.5" />
        </.toolbar_button>
        <.toolbar_button label="Reset">
          <Icons.icon_fmt_reset class="w-3.5 h-3.5" />
        </.toolbar_button>
        <.toolbar_button label="Strip formatting">
          <Icons.icon_fmt_strip class="w-3.5 h-3.5" />
        </.toolbar_button>

        <.toolbar_separator />

        <%!-- Emoji toggle --%>
        <.toolbar_button label="Emoji">
          <Icons.icon_fmt_emoji class="w-3.5 h-3.5" />
        </.toolbar_button>
      </.toolbar>

      <%!-- Color picker panel (shown when toggled) --%>
      <div :if={@show_color_picker}>
        <.color_picker id="formatting-color-picker" selected={@selected_color} />
      </div>
    </div>
    """
  end
end

defmodule RetroHexChatWeb.Components.UI.FormattingToolbar do
  @moduledoc """
  Formatting toolbar component for the showcase design system.

  Renders a single compact trigger plus a popover toolbar. Hook-compatible with FormatToolbarHook:
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

  @color_keys [
    :white,
    :black,
    :navy,
    :green,
    :red,
    :brown,
    :purple,
    :orange,
    :yellow,
    :light_green,
    :teal,
    :light_cyan,
    :blue,
    :pink,
    :grey,
    :light_grey
  ]

  @doc "Renders the formatting toolbar."
  attr :id, :string, default: "formatting-toolbar"
  attr :bold_active, :boolean, default: false
  attr :italic_active, :boolean, default: false
  attr :underline_active, :boolean, default: false
  attr :strip_active, :boolean, default: false
  attr :content_format, :string, default: "irc"
  attr :composer_view, :any, default: :write
  attr :show_emoji, :boolean, default: true, doc: "Render the emoji-picker toggle button"
  attr :on_format, :any, default: nil, doc: "Format button callback (receives phx-value-format)"
  attr :on_content_format, :any, default: nil, doc: "Composer content format callback"
  attr :on_composer_view, :any, default: nil, doc: "Markdown preview/write callback"
  attr :on_toggle_emoji, :any, default: nil, doc: "Emoji picker toggle callback"
  attr :target, :any, default: nil, doc: "LiveComponent target for composer-owned events"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec formatting_toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def formatting_toolbar(assigns) do
    assigns =
      assigns
      |> assign(:color_names, Enum.map(@color_keys, &color_name/1))
      |> assign(:panel_id, "#{assigns.id}-panel")
      |> assign(:color_panel_id, "#{assigns.id}-color-panel")
      |> assign(:content_format, normalize_content_format(assigns.content_format))
      |> assign(:composer_view, normalize_composer_view(assigns.composer_view))

    ~H"""
    <div
      class={classes(["formatting-toolbar block", @class])}
      phx-hook="FormatToolbarHook"
      id={@id}
      {@rest}
    >
      <.toolbar variant="compact" class="formatting-toolbar__trigger-row">
        <.toolbar_button
          variant="compact"
          label={dgettext("chat", "Formatting Toolbar")}
          class="formatting-toolbar__toggle"
          data-format-toolbar-toggle
          data-testid="formatting-toolbar-toggle"
          data-active-format={@content_format}
          aria-controls={@panel_id}
          aria-expanded="false"
          aria-haspopup="true"
        >
          <Icons.icon_fmt_toolbar class="w-3.5 h-3.5" />
        </.toolbar_button>
      </.toolbar>

      <div
        id={@panel_id}
        class="formatting-toolbar__panel u-hidden"
        data-format-toolbar-panel
        data-testid="formatting-toolbar-panel"
        aria-hidden="true"
      >
        <div class="formatting-toolbar__section">
          <div
            class={
              classes([
                "formatting-toolbar__mode-row",
                @content_format == "markdown" && "formatting-toolbar__mode-row--with-preview"
              ])
            }
            data-testid="composer-format-selector"
            data-active-format={@content_format}
            aria-label={dgettext("chat", "Message format")}
          >
            <button
              :for={format <- content_format_options()}
              type="button"
              class={format_mode_button_class(@content_format == format)}
              phx-click={@on_content_format}
              phx-value-format={format}
              phx-target={@target}
              aria-pressed={@content_format == format}
              data-format-toolbar-live="true"
              data-testid={"composer-format-#{format}"}
              title={format_title(format)}
            >
              <%= case format do %>
                <% "irc" -> %>
                  <Icons.icon_fmt_mode_irc class="w-3.5 h-3.5" />
                <% "markdown" -> %>
                  <Icons.icon_fmt_mode_markdown class="w-3.5 h-3.5" />
                <% "plain" -> %>
                  <Icons.icon_fmt_mode_plain class="w-3.5 h-3.5" />
              <% end %>
              <span class="sr-only">{format_title(format)}</span>
            </button>

            <button
              :if={@content_format == "markdown"}
              type="button"
              class={preview_toggle_class(@composer_view == :preview)}
              phx-click={@on_composer_view}
              phx-value-view={if(@composer_view == :preview, do: "write", else: "preview")}
              phx-target={@target}
              aria-pressed={@composer_view == :preview}
              data-format-toolbar-close
              data-testid="composer-markdown-preview-toggle"
              title={dgettext("chat", "Markdown preview")}
            >
              <Icons.icon_fmt_preview class="w-3.5 h-3.5" />
              <span class="sr-only">
                {if @composer_view == :preview,
                  do: dgettext("chat", "Write"),
                  else: dgettext("chat", "Preview")}
              </span>
            </button>
          </div>
        </div>

        <.toolbar
          variant="compact"
          class="formatting-toolbar__section formatting-toolbar__actions"
          aria-label={dgettext("chat", "Text formatting")}
        >
          <%= case @content_format do %>
            <% "markdown" -> %>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Heading")}
                class="format-btn"
                data-format-code="md-heading"
                data-testid="format-btn-md-heading"
              >
                <Icons.icon_fmt_heading class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Bold")}
                class="format-btn"
                data-format-code="md-bold"
                data-testid="format-btn-md-bold"
              >
                <Icons.icon_fmt_bold class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Italic")}
                class="format-btn"
                data-format-code="md-italic"
                data-testid="format-btn-md-italic"
              >
                <Icons.icon_fmt_italic class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Strikethrough")}
                class="format-btn"
                data-format-code="md-strike"
                data-testid="format-btn-md-strike"
              >
                <Icons.icon_fmt_strike class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Inline code")}
                class="format-btn"
                data-format-code="md-code"
                data-testid="format-btn-md-code"
              >
                <Icons.icon_fmt_inline_code class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Code block")}
                class="format-btn"
                data-format-code="md-code-block"
                data-testid="format-btn-md-code-block"
              >
                <Icons.icon_fmt_code_block class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Quote")}
                class="format-btn"
                data-format-code="md-quote"
                data-testid="format-btn-md-quote"
              >
                <Icons.icon_fmt_quote class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Bulleted list")}
                class="format-btn"
                data-format-code="md-list"
                data-testid="format-btn-md-list"
              >
                <Icons.icon_fmt_bulleted_list class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Numbered list")}
                class="format-btn"
                data-format-code="md-ordered-list"
                data-testid="format-btn-md-ordered-list"
              >
                <Icons.icon_fmt_ordered_list class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Link")}
                class="format-btn"
                data-format-code="md-link"
                data-testid="format-btn-md-link"
              >
                <Icons.icon_link class="w-3.5 h-3.5" />
              </.toolbar_button>
            <% "irc" -> %>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Bold (Ctrl+Shift+B)")}
                active={@bold_active}
                class="format-btn"
                data-format-code="bold"
                data-testid="format-btn-bold"
              >
                <Icons.icon_fmt_bold class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Italic (Ctrl+Shift+Y)")}
                active={@italic_active}
                class="format-btn"
                data-format-code="italic"
                data-testid="format-btn-italic"
              >
                <Icons.icon_fmt_italic class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Underline (Ctrl+Shift+U)")}
                active={@underline_active}
                class="format-btn"
                data-format-code="underline"
                data-testid="format-btn-underline"
              >
                <Icons.icon_fmt_underline class="w-3.5 h-3.5" />
              </.toolbar_button>

              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Color (Ctrl+Shift+D)")}
                class="format-btn"
                data-format-code="color"
                data-testid="format-btn-color"
                aria-controls={@color_panel_id}
                aria-expanded="false"
                aria-haspopup="true"
              >
                <Icons.icon_fmt_color class="w-3.5 h-3.5" />
              </.toolbar_button>

              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Reverse (Ctrl+Shift+V)")}
                class="format-btn"
                data-format-code="reverse"
                data-testid="format-btn-reverse"
              >
                <Icons.icon_fmt_reverse class="w-3.5 h-3.5" />
              </.toolbar_button>
              <.toolbar_button
                variant="compact"
                label={dgettext("chat", "Reset (Ctrl+Shift+X)")}
                class="format-btn"
                data-format-code="reset"
                data-testid="format-btn-reset"
              >
                <Icons.icon_fmt_reset class="w-3.5 h-3.5" />
              </.toolbar_button>
            <% _plain -> %>
          <% end %>

          <.toolbar_separator :if={@content_format != "plain"} variant="compact" />

          <.toolbar_button
            variant="compact"
            label={dgettext("chat", "Strip Formatting")}
            active={@strip_active}
            phx-click={@on_format}
            phx-value-format="strip"
            data-testid="strip-formatting-toggle"
          >
            <Icons.icon_fmt_strip class="w-3.5 h-3.5" />
          </.toolbar_button>

          <.toolbar_button
            :if={@show_emoji}
            variant="compact"
            label={dgettext("chat", "Emoji Picker")}
            phx-click={@on_toggle_emoji}
            data-emoji-toggle="true"
            data-format-toolbar-close
            data-testid="emoji-picker-toggle"
          >
            <Icons.icon_fmt_emoji class="w-3.5 h-3.5" />
          </.toolbar_button>
        </.toolbar>

        <div
          :if={@content_format == "irc"}
          id={@color_panel_id}
          class="format-color-dropdown"
          data-format-color-dropdown
          aria-label={dgettext("chat", "IRC colors")}
        >
          <button
            :for={{name, i} <- Enum.with_index(@color_names)}
            type="button"
            class={"w-4 h-4 border border-gray-900 shadow-retro-field cursor-pointer irc-bg-#{i}"}
            data-color-code={to_string(i)}
            data-format-color-swatch
            data-testid={"format-color-swatch-#{i}"}
            title={name}
            aria-label={name}
          >
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp color_name(:white), do: dgettext("chat", "White")
  defp color_name(:black), do: dgettext("chat", "Black")
  defp color_name(:navy), do: dgettext("chat", "Navy")
  defp color_name(:green), do: dgettext("chat", "Green")
  defp color_name(:red), do: dgettext("chat", "Red")
  defp color_name(:brown), do: dgettext("chat", "Brown")
  defp color_name(:purple), do: dgettext("chat", "Purple")
  defp color_name(:orange), do: dgettext("chat", "Orange")
  defp color_name(:yellow), do: dgettext("chat", "Yellow")
  defp color_name(:light_green), do: dgettext("chat", "Light Green")
  defp color_name(:teal), do: dgettext("chat", "Teal")
  defp color_name(:light_cyan), do: dgettext("chat", "Light Cyan")
  defp color_name(:blue), do: dgettext("chat", "Blue")
  defp color_name(:pink), do: dgettext("chat", "Pink")
  defp color_name(:grey), do: dgettext("chat", "Grey")
  defp color_name(:light_grey), do: dgettext("chat", "Light Grey")

  defp content_format_options, do: ~w(irc markdown plain)

  defp format_title("irc"), do: dgettext("chat", "IRC formatting")
  defp format_title("markdown"), do: dgettext("chat", "Markdown formatting")
  defp format_title("plain"), do: dgettext("chat", "Plain text")

  defp format_mode_button_class(true),
    do: "formatting-toolbar__mode-button formatting-toolbar__mode-button--active"

  defp format_mode_button_class(false), do: "formatting-toolbar__mode-button"

  defp preview_toggle_class(true),
    do: "formatting-toolbar__preview-button formatting-toolbar__preview-button--active"

  defp preview_toggle_class(false), do: "formatting-toolbar__preview-button"

  defp normalize_content_format(format) when format in ~w(irc markdown plain), do: format
  defp normalize_content_format(_format), do: "irc"

  defp normalize_composer_view(:preview), do: :preview
  defp normalize_composer_view("preview"), do: :preview
  defp normalize_composer_view(_view), do: :write
end

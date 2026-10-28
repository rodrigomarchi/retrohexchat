defmodule RetroHexChatWeb.Components.UI.AsciiArt do
  @moduledoc """
  ASCII Art's window: its menu bar, what the art is made from — text, a
  picture, or the Hex Paint drawing — the preview, and its status line.

  As in Hex Paint, the art is made in the browser (`lib/ascii_art/`, through
  `AsciiArtHook`): a menu item sends an `ascii:command` to the hook root, and
  only Post goes to the server, from the window's island.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.Paint, only: [colour_swatches: 1]
  import RetroHexChatWeb.Components.UI.Window, only: [window_status_bar_field: 1]
  import RetroHexChatWeb.Components.UI.Form, only: [form_description: 1]
  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Label
  import RetroHexChatWeb.Components.UI.Select
  import RetroHexChatWeb.Components.UI.Slider
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Textarea

  alias RetroHexChat.Chat.Content.IrcArt
  alias RetroHexChatWeb.Icons

  @root "#ascii-art-root"

  @doc "A command for the art, sent from a menu item or a button."
  @spec command(String.t()) :: Phoenix.LiveView.JS.t()
  def command(name), do: JS.dispatch("ascii:command", to: @root, detail: %{command: name})

  attr :id, :string, default: "ascii-art-menubar"

  @spec ascii_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def ascii_menu_bar(assigns) do
    ~H"""
    <.menu_bar id={@id} testid="ascii-art-menu-bar" class="app-menu-bar" phx-hook="MenuBarHook">
      <.mobile_menu_drawer menu_id={@id} sections={sections()} active_section="file">
        <:section id="file"><.file_items /></:section>
        <:section id="edit"><.edit_items /></:section>
      </.mobile_menu_drawer>
      <.mobile_menu_rail sections={sections()} />

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "File")}>
        <:icon><Icons.icon_folder class="h-4 w-4" /></:icon>
        <.file_items />
      </.menu>
      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "Edit")}>
        <:icon><Icons.icon_copy class="h-4 w-4" /></:icon>
        <.edit_items />
      </.menu>
    </.menu_bar>
    """
  end

  defp sections do
    [
      %{id: "file", label: dgettext("ui", "File"), icon_fn: :icon_folder},
      %{id: "edit", label: dgettext("ui", "Edit"), icon_fn: :icon_copy}
    ]
  end

  defp file_items(assigns) do
    ~H"""
    <.context_menu_item on_click={command("post")} testid="ascii-art-menu-post">
      <:icon><Icons.icon_file_send class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Post to channel…")}
    </.context_menu_item>
    """
  end

  defp edit_items(assigns) do
    ~H"""
    <.context_menu_item on_click={command("copy")} testid="ascii-art-menu-copy">
      <:icon><Icons.icon_copy class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Copy")}
    </.context_menu_item>
    <.context_menu_item on_click={command("clear")} testid="ascii-art-menu-clear">
      <:icon><Icons.icon_trash class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Clear")}
    </.context_menu_item>
    """
  end

  @doc """
  What the art is made from — a tab each for text, a picture and the Hex
  Paint drawing — and the preview of it. A tab sends `ascii:source` to the
  hook root as it opens; the browser draws the preview, so the server leaves
  it as it drew it.
  """
  @spec ascii_body(map()) :: Phoenix.LiveView.Rendered.t()
  def ascii_body(assigns) do
    assigns = assign(assigns, max_columns: IrcArt.max_columns())

    ~H"""
    <div class="ascii-art flex min-h-0 flex-1 flex-col gap-retro-6">
      <.tabs :let={builder} id="ascii-art-sources" default="text" data-testid="ascii-art-sources">
        <.tabs_list>
          <.tabs_trigger
            :for={{value, label, icon} <- sources()}
            builder={builder}
            value={value}
            phx-click={source(value)}
            data-testid={"ascii-art-source-#{value}"}
          >
            <:icon>{apply(Icons, icon, [%{class: "h-4 w-4"}])}</:icon>
            {label}
          </.tabs_trigger>
        </.tabs_list>

        <%!-- A panel's display is the tabs' (hidden or shown); the layout is
              its child's. --%>
        <.tabs_content builder={builder} value="text">
          <div class="flex flex-col gap-retro-6">
            <.textarea
              name="ascii-text"
              rows="2"
              maxlength="120"
              placeholder={dgettext("ui", "Type a word or two")}
              aria-label={dgettext("ui", "Text")}
              class="min-h-0 resize-none"
              data-testid="ascii-art-text"
            />
            <div class="flex flex-wrap items-center gap-retro-8">
              <.choice
                name="ascii-style"
                label={dgettext("ui", "Style:")}
                options={[
                  {"block", dgettext("ui", "Solid blocks")},
                  {"hash", dgettext("ui", "Hash marks")},
                  {"shadow", dgettext("ui", "With a shadow")}
                ]}
              />
              <.choice
                name="ascii-scheme"
                label={dgettext("ui", "Colours:")}
                options={[
                  {"single", dgettext("ui", "One colour")},
                  {"background", dgettext("ui", "On a background")},
                  {"rainbow", dgettext("ui", "Rainbow")},
                  {"gradient", dgettext("ui", "Two tones")}
                ]}
              />
              <.colour_swatches id="ascii-art-palette" />
            </div>
          </div>
        </.tabs_content>

        <.tabs_content builder={builder} value="image">
          <div class="flex flex-col gap-retro-6">
            <div class="flex flex-wrap items-center gap-retro-8">
              <.label class="flex items-center gap-retro-4" for="ascii-art-file">
                {dgettext("ui", "Picture:")}
              </.label>
              <.input
                id="ascii-art-file"
                type="file"
                name="ascii-file"
                accept="image/*"
                data-testid="ascii-art-file"
              />
              <.label class="flex items-center gap-retro-4" for="ascii-art-columns">
                {dgettext("ui", "Width:")}
              </.label>
              <.slider
                id="ascii-art-columns"
                name="ascii-columns"
                min={20}
                max={@max_columns}
                step={2}
                value={60}
                class="w-32"
                data-testid="ascii-art-columns"
              />
              <.choice
                name="ascii-mode"
                label={dgettext("ui", "Drawn in:")}
                options={[
                  {"colour", dgettext("ui", "Colour blocks")},
                  {"ramp", dgettext("ui", "Characters")}
                ]}
              />
            </div>
            <.form_description>
              {dgettext(
                "ui",
                "The picture stays on this computer: only the art made from it is posted."
              )}
            </.form_description>
          </div>
        </.tabs_content>

        <.tabs_content builder={builder} value="paint">
          <.form_description>
            {dgettext("ui", "The drawing open in Hex Paint, two pixels to a character.")}
          </.form_description>
        </.tabs_content>
      </.tabs>

      <.inset
        id="ascii-art-preview"
        bevel="sunken"
        tone="paper"
        class="ascii-art__preview min-h-0 flex-1 overflow-auto"
        phx-update="ignore"
        data-ascii-preview
        data-testid="ascii-art-preview"
      >
      </.inset>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :options, :list, required: true, doc: "`{value, label}`, the first chosen"

  # A labelled choice of a few words, owned by the browser like the rest of
  # the window's controls.
  defp choice(assigns) do
    assigns = assign(assigns, first: hd(assigns.options))

    ~H"""
    <div class="flex items-center gap-retro-4">
      <.label for={@name}>{@label}</.label>
      <.select
        :let={builder}
        id={@name}
        name={@name}
        value={elem(@first, 0)}
        label={elem(@first, 1)}
        class="w-36"
        data-testid={@name}
      >
        <.select_trigger builder={builder} class="h-7 text-xs" />
        <.select_content builder={builder}>
          <.select_group>
            <.select_item
              :for={{value, label} <- @options}
              builder={builder}
              value={value}
              label={label}
            >
              {label}
            </.select_item>
          </.select_group>
        </.select_content>
      </.select>
    </div>
    """
  end

  defp source(value), do: JS.dispatch("ascii:source", to: @root, detail: %{source: value})

  @doc "The status line: how many columns and lines the art takes."
  @spec ascii_status(map()) :: Phoenix.LiveView.Rendered.t()
  def ascii_status(assigns) do
    ~H"""
    <.window_status_bar_field id="ascii-art-status-size" phx-update="ignore" data-ascii-status="size">
      &nbsp;
    </.window_status_bar_field>
    <.window_status_bar_field grow>
      {dgettext("ui", "Up to %{lines} lines of %{columns} characters",
        lines: IrcArt.max_lines(),
        columns: IrcArt.max_columns()
      )}
    </.window_status_bar_field>
    """
  end

  defp sources do
    [
      {"text", dgettext("ui", "Text"), :icon_notepad},
      {"image", dgettext("ui", "Picture"), :icon_choose_file},
      {"paint", "Hex Paint", :icon_paint}
    ]
  end
end

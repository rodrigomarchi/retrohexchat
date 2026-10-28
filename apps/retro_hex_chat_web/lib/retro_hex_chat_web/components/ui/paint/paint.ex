defmodule RetroHexChatWeb.Components.UI.Paint do
  @moduledoc """
  Hex Paint's window: its menu bar, its tools, its sixteen colours, the
  drawing and the status line under it.

  The drawing lives in the browser (`lib/paint/`, through `PaintHook`), so
  nothing here is a server event: a menu item or a tool sends a `paint:command`
  to the hook root (`JS.dispatch`), and the status fields are written there.
  Only Post goes to the server, from the window's island.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.MenuBar
  import RetroHexChatWeb.Components.UI.ContextMenu
  import RetroHexChatWeb.Components.UI.ToolButton
  import RetroHexChatWeb.Components.UI.ColorPicker, only: [color_picker: 1, colour_pair: 1]
  import RetroHexChatWeb.Components.UI.Inset
  import RetroHexChatWeb.Components.UI.Window, only: [window_status_bar_field: 1]

  alias RetroHexChatWeb.Icons

  @root "#hex-paint"

  @doc "The element the menu and the tools send their commands to."
  @spec root() :: String.t()
  def root, do: @root

  @doc "A command for the drawing, sent from a menu item or a button."
  @spec command(String.t(), map()) :: Phoenix.LiveView.JS.t()
  def command(name, detail \\ %{}),
    do: JS.dispatch("paint:command", to: @root, detail: Map.put(detail, :command, name))

  attr :id, :string, default: "hex-paint-menubar"

  @spec paint_menu_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def paint_menu_bar(assigns) do
    ~H"""
    <.menu_bar id={@id} testid="hex-paint-menu-bar" class="app-menu-bar" phx-hook="MenuBarHook">
      <.mobile_menu_drawer menu_id={@id} sections={sections()} active_section="file">
        <:section id="file"><.file_items /></:section>
        <:section id="edit"><.edit_items /></:section>
        <:section id="view"><.view_items /></:section>
      </.mobile_menu_drawer>
      <.mobile_menu_rail sections={sections()} />

      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "File")}>
        <:icon><Icons.icon_folder class="h-4 w-4" /></:icon>
        <.file_items />
      </.menu>
      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "Edit")}>
        <:icon><Icons.icon_paint_undo class="h-4 w-4" /></:icon>
        <.edit_items />
      </.menu>
      <.menu class="app-menu-bar__desktop-menu" label={dgettext("ui", "View")}>
        <:icon><Icons.icon_paint_zoom_in class="h-4 w-4" /></:icon>
        <.view_items />
      </.menu>
    </.menu_bar>
    """
  end

  defp sections do
    [
      %{id: "file", label: dgettext("ui", "File"), icon_fn: :icon_folder},
      %{id: "edit", label: dgettext("ui", "Edit"), icon_fn: :icon_paint_undo},
      %{id: "view", label: dgettext("ui", "View"), icon_fn: :icon_paint_zoom_in}
    ]
  end

  defp file_items(assigns) do
    ~H"""
    <.context_menu_item
      :for={size <- [32, 64, 128]}
      on_click={command("new", %{size: size})}
      testid={"hex-paint-menu-new-#{size}"}
    >
      <:icon><Icons.icon_notepad class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "New %{size}×%{size}", size: size)}
    </.context_menu_item>
    <.context_menu_separator />
    <.context_menu_item on_click={command("save")} testid="hex-paint-menu-save">
      <:icon><Icons.icon_btn_save class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Save as PNG")}
    </.context_menu_item>
    <.context_menu_item on_click={command("post")} testid="hex-paint-menu-post">
      <:icon><Icons.icon_file_send class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Post to channel…")}
    </.context_menu_item>
    <.context_menu_item on_click={command("ascii")} testid="hex-paint-menu-to-ascii">
      <:icon><Icons.icon_ascii_art class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Open in ASCII Art")}
    </.context_menu_item>
    """
  end

  defp edit_items(assigns) do
    ~H"""
    <.context_menu_item on_click={command("undo")} testid="hex-paint-menu-undo">
      <:icon><Icons.icon_paint_undo class="h-[14px] w-[14px]" /></:icon>
      <:shortcut>{dgettext("ui", "Ctrl+Z")}</:shortcut>
      {dgettext("ui", "Undo")}
    </.context_menu_item>
    <.context_menu_item on_click={command("redo")} testid="hex-paint-menu-redo">
      <:icon><Icons.icon_paint_redo class="h-[14px] w-[14px]" /></:icon>
      <:shortcut>{dgettext("ui", "Ctrl+Y")}</:shortcut>
      {dgettext("ui", "Redo")}
    </.context_menu_item>
    <.context_menu_separator />
    <.context_menu_item on_click={command("clear")} testid="hex-paint-menu-clear">
      <:icon><Icons.icon_trash class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Clear")}
    </.context_menu_item>
    """
  end

  defp view_items(assigns) do
    ~H"""
    <.context_menu_item on_click={command("grid")} testid="hex-paint-menu-grid">
      <:icon><Icons.icon_table_grid class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Grid")}
    </.context_menu_item>
    <.context_menu_item on_click={command("zoom", %{by: 1})} testid="hex-paint-menu-zoom-in">
      <:icon><Icons.icon_paint_zoom_in class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Zoom in")}
    </.context_menu_item>
    <.context_menu_item on_click={command("zoom", %{by: -1})} testid="hex-paint-menu-zoom-out">
      <:icon><Icons.icon_paint_zoom_out class="h-[14px] w-[14px]" /></:icon>
      {dgettext("ui", "Zoom out")}
    </.context_menu_item>
    """
  end

  @doc "The tools, the colours and the drawing: the window's body, inside the hook root."
  attr :tools, :list, required: true

  @spec paint_canvas(map()) :: Phoenix.LiveView.Rendered.t()
  def paint_canvas(assigns) do
    ~H"""
    <div class="hex-paint flex min-h-0 flex-1 gap-retro-4">
      <%!-- The chosen tool is pressed by the browser (aria-pressed), so the
            server leaves this strip as it drew it. --%>
      <div
        id="hex-paint-tools"
        class="hex-paint__tools grid shrink-0 content-start gap-retro-2"
        role="toolbar"
        aria-label={dgettext("ui", "Tools")}
        phx-update="ignore"
        data-testid="hex-paint-tools"
      >
        <.tool_button
          :for={tool <- @tools}
          label={tool.label}
          variant="flat"
          size="sm"
          pressed={tool.id == "pencil"}
          data-paint-tool={tool.id}
          phx-click={command("tool", %{tool: tool.id})}
          data-testid={"hex-paint-tool-#{tool.id}"}
        >
          {apply(Icons, tool.icon, [%{class: "h-4 w-4"}])}
        </.tool_button>
        <.tool_button
          label={dgettext("ui", "Mirror")}
          variant="flat"
          size="sm"
          pressed={false}
          data-paint-toggle="mirror"
          phx-click={command("mirror")}
          data-testid="hex-paint-mirror"
        >
          <Icons.icon_paint_mirror class="h-4 w-4" />
        </.tool_button>
      </div>

      <div class="flex min-h-0 min-w-0 flex-1 flex-col gap-retro-4">
        <.inset
          id="hex-paint-stage"
          bevel="sunken"
          tone="canvas"
          class="hex-paint__stage min-h-0 flex-1 overflow-auto"
          phx-update="ignore"
          data-testid="hex-paint-stage"
        >
          <canvas
            data-paint-canvas
            class="hex-paint__canvas"
            aria-label={dgettext("ui", "Drawing")}
            data-testid="hex-paint-canvas"
          ></canvas>
        </.inset>

        <.colour_swatches id="hex-paint-palette" />
      </div>
    </div>
    """
  end

  @doc """
  The sixteen colours and the two chosen ones — Hex Paint's and ASCII Art's.
  The left button chooses the foreground (the picker's own choice), the right
  button the background; the browser reads the colours from the swatches
  (`lib/paint/palette.js`) and paints the pair, so the server leaves the strip
  as it drew it.
  """
  attr :id, :string, required: true

  @spec colour_swatches(map()) :: Phoenix.LiveView.Rendered.t()
  def colour_swatches(assigns) do
    ~H"""
    <div id={@id} class="flex items-center gap-retro-6" phx-update="ignore" data-testid={@id}>
      <.colour_pair />
      <.color_picker id={"#{@id}-colours"} field={"#{@id}-fg"} selected={1} />
    </div>
    """
  end

  @doc "The status line: the drawing's size, the pixel under the pointer, the tool."
  @spec paint_status(map()) :: Phoenix.LiveView.Rendered.t()
  def paint_status(assigns) do
    ~H"""
    <.window_status_bar_field id="hex-paint-status-size" phx-update="ignore" data-paint-status="size">
      32×32
    </.window_status_bar_field>
    <.window_status_bar_field id="hex-paint-status-at" phx-update="ignore" data-paint-status="at" grow>
      &nbsp;
    </.window_status_bar_field>
    <.window_status_bar_field id="hex-paint-status-tool" phx-update="ignore" data-paint-status="tool">
      {dgettext("ui", "Pencil")}
    </.window_status_bar_field>
    """
  end

  @doc "Hex Paint's tools, in the toolbar's order, with their names and icons."
  @spec tools() :: [%{id: String.t(), label: String.t(), icon: atom()}]
  def tools do
    [
      %{id: "pencil", label: dgettext("ui", "Pencil (P)"), icon: :icon_paint_pencil},
      %{id: "line", label: dgettext("ui", "Line (L)"), icon: :icon_paint_line},
      %{id: "rect", label: dgettext("ui", "Rectangle (R)"), icon: :icon_paint_rect},
      %{
        id: "rect_fill",
        label: dgettext("ui", "Filled rectangle (Shift+R)"),
        icon: :icon_paint_rect_fill
      },
      %{id: "ellipse", label: dgettext("ui", "Ellipse (E)"), icon: :icon_paint_ellipse},
      %{
        id: "ellipse_fill",
        label: dgettext("ui", "Filled ellipse (Shift+E)"),
        icon: :icon_paint_ellipse_fill
      },
      %{id: "bucket", label: dgettext("ui", "Fill (B)"), icon: :icon_paint_bucket},
      %{id: "eraser", label: dgettext("ui", "Eraser (X)"), icon: :icon_paint_eraser},
      %{id: "picker", label: dgettext("ui", "Pick colour (I)"), icon: :icon_paint_picker}
    ]
  end
end

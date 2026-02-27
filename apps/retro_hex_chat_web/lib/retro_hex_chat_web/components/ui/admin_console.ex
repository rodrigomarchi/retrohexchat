defmodule RetroHexChatWeb.Components.UI.AdminConsole do
  @moduledoc """
  Admin console dialog component for the showcase design system.

  Composed from dialog + input + scroll_area primitives.
  Terminal-like interface with server commands.

  ## Usage

      <.admin_console id="admin-console" show={true} lines={@log_lines} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Input
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the admin console dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :lines, :list, default: []
  attr :command, :string, default: ""

  @spec admin_console(map()) :: Phoenix.LiveView.Rendered.t()
  def admin_console(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_dialog_admin_console class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>Admin Console</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body>
        <%!-- Terminal output --%>
        <div class="shadow-retro-field bg-canvas-bg text-canvas-fg h-[250px] overflow-y-auto retro-scrollbar p-retro-4 font-mono text-xs">
          <div :for={line <- @lines} class="whitespace-pre-wrap">
            {line}
          </div>
        </div>

        <%!-- Command input --%>
        <div class="flex items-center gap-retro-4 mt-retro-4">
          <span class="text-xs font-mono font-bold shrink-0">&gt;</span>
          <.input type="text" value={@command} placeholder="Enter command..." class="flex-1 font-mono" />
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_send class="w-4 h-4" /></:icon>
            Send
          </.button>
        </div>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="outline" phx-click={hide_modal(@id)}>
          <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
          Close
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end

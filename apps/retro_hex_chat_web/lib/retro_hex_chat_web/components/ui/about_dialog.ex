defmodule RetroHexChatWeb.Components.UI.AboutDialog do
  @moduledoc """
  About dialog component for the showcase design system.

  Composed from dialog + separator primitives.
  Shows logo, version, and credits.

  ## Usage

      <.about_dialog id="about" show={true} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Separator
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders the about dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :version, :string, default: "2.0.0"

  @spec about_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def about_dialog(assigns) do
    ~H"""
    <.dialog id={@id} show={@show}>
      <.dialog_header>
        <.dialog_icon>
          <Icons.icon_lightbulb class="w-4 h-4" />
        </.dialog_icon>
        <.dialog_title>About RetroHexChat</.dialog_title>
        <.dialog_close id={@id} />
      </.dialog_header>

      <.dialog_body class="text-center space-y-retro-8">
        <div class="flex justify-center">
          <Icons.icon_chat class="w-12 h-12" />
        </div>

        <div class="space-y-retro-2">
          <p class="text-sm font-bold">RetroHexChat</p>
          <p class="text-xs text-muted-foreground">Version {@version}</p>
        </div>

        <.separator />

        <div class="text-xs text-muted-foreground space-y-retro-2">
          <p>A retro-styled IRC chat client</p>
          <p>Built with Phoenix LiveView</p>
        </div>

        <.separator />

        <p class="text-[10px] text-muted-foreground">
          &copy; 2024-2026 RetroHexChat Contributors
        </p>
      </.dialog_body>

      <.dialog_footer>
        <.button variant="default" phx-click={hide_modal(@id)}>
          <:icon><Icons.icon_checkmark class="w-4 h-4" /></:icon>
          OK
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end
end

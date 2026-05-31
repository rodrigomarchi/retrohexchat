defmodule RetroHexChatWeb.Components.UI.DisconnectConfirmDialog do
  @moduledoc """
  Disconnect confirmation dialog for the showcase design system.

  Composed from dialog + button primitives. Prompts the user to confirm
  disconnecting from the IRC server, with a warning and destructive action button.

  ## Usage

      <.disconnect_confirm_dialog
        id="disconnect-confirm"
        show={true}
        on_confirm={JS.push("disconnect_server")}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  @doc "Renders a disconnect confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_confirm, :any, default: nil, doc: "JS command or event name for confirm"

  attr :on_cancel, :any,
    default: nil,
    doc: "JS command or event name for cancel (default: hide modal)"

  @spec disconnect_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def disconnect_confirm_dialog(assigns) do
    ~H"""
    <span data-testid="disconnect-confirm-dialog">
      <.dialog id={@id} show={@show}>
        <.dialog_header id={@id} title={dgettext("dialogs", "Disconnect from Server")}>
          <:icon><Icons.icon_btn_disconnect class="w-[16px] h-[16px]" /></:icon>
        </.dialog_header>

        <.dialog_body>
          <p class="text-xs">
            {dgettext("dialogs", "Are you sure you want to disconnect from the server?")}
          </p>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="destructive"
            phx-click={@on_confirm}
            data-testid="disconnect-confirm-dialog-confirm"
          >
            <:icon><Icons.icon_btn_disconnect class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Disconnect")}
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel || hide_modal(@id)}
            data-testid="disconnect-confirm-dialog-cancel"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            {dgettext("dialogs", "Cancel")}
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end
end

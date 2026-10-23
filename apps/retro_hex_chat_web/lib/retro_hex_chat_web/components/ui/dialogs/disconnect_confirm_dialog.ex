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

  import RetroHexChatWeb.Components.UI.ConfirmDialog

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
    <.confirm_dialog
      id={@id}
      show={@show}
      testid="disconnect-confirm-dialog"
      title={dgettext("dialogs", "Disconnect from Server")}
      message={dgettext("dialogs", "Are you sure you want to disconnect from the server?")}
      icon={:icon_btn_disconnect}
      variant="destructive"
      confirm_label={dgettext("dialogs", "Disconnect")}
      confirm_icon={:icon_btn_disconnect}
      on_confirm={@on_confirm}
      on_cancel={@on_cancel}
    >
      <:note>{dgettext("dialogs", "Your current chat session will end.")}</:note>
    </.confirm_dialog>
    """
  end
end

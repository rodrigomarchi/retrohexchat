defmodule RetroHexChatWeb.Components.UI.DeleteConfirmDialog do
  @moduledoc """
  Delete message confirmation dialog for the showcase design system.

  Composed from dialog + button primitives. Prompts the user to confirm
  deletion of a message with a warning that the action cannot be undone.

  ## Usage

      <.delete_confirm_dialog
        id="delete-msg"
        show={true}
        message_id={42}
        on_confirm={JS.push("delete_message", value: %{id: 42})}
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ConfirmDialog

  @doc "Renders a delete message confirmation dialog."
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :message_id, :any, default: nil, doc: "ID of the message to be deleted"
  attr :on_confirm, :any, default: nil, doc: "JS command or event name for confirm"

  attr :on_cancel, :any,
    default: nil,
    doc: "JS command or event name for cancel (default: hide modal)"

  @spec delete_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def delete_confirm_dialog(assigns) do
    ~H"""
    <.confirm_dialog
      id={@id}
      show={@show}
      testid="delete-confirm-dialog"
      title={dgettext("dialogs", "Delete Message")}
      message={dgettext("dialogs", "Are you sure you want to delete this message?")}
      icon={:icon_dialog_delete}
      variant="destructive"
      confirm_label={dgettext("dialogs", "Delete")}
      confirm_icon={:icon_dialog_delete}
      on_confirm={@on_confirm}
      on_cancel={@on_cancel}
    >
      <:note>{dgettext("dialogs", "This action cannot be undone.")}</:note>
    </.confirm_dialog>
    """
  end
end

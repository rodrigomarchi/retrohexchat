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

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

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
    <span data-testid="delete-confirm-dialog">
      <.dialog id={@id} show={@show}>
        <.dialog_header>
          <.dialog_icon>
            <Icons.icon_dialog_delete class="w-[16px] h-[16px]" />
          </.dialog_icon>
          <.dialog_title>Delete Message</.dialog_title>
          <.dialog_close id={@id} />
        </.dialog_header>

        <.dialog_body>
          <p class="text-xs">
            Are you sure you want to delete this message? This action cannot be undone.
          </p>
        </.dialog_body>

        <.dialog_footer>
          <.button
            variant="destructive"
            phx-click={@on_confirm}
            data-testid="delete-confirm-dialog-confirm"
          >
            <:icon><Icons.icon_dialog_delete class="w-4 h-4" /></:icon>
            Delete
          </.button>
          <.button
            variant="outline"
            phx-click={@on_cancel || hide_modal(@id)}
            data-testid="delete-confirm-dialog-cancel"
          >
            <:icon><Icons.icon_close class="w-4 h-4" /></:icon>
            Cancel
          </.button>
        </.dialog_footer>
      </.dialog>
    </span>
    """
  end
end

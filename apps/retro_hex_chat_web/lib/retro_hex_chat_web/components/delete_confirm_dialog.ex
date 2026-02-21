defmodule RetroHexChatWeb.Components.DeleteConfirmDialog do
  @moduledoc """
  Delete confirmation dialog: "Delete this message?" with Confirmar/Cancelar.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false
  attr :message_id, :any, default: nil

  @spec delete_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def delete_confirm_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      phx-window-keydown="cancel_delete"
      phx-key="Escape"
      data-testid="delete-confirm-dialog"
    >
      <div class="window delete-confirm-dialog">
        <div class="title-bar">
          <Icons.icon_dialog_delete class="title-bar-icon" />
          <div class="title-bar-text">Confirm</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cancel_delete"></button>
          </div>
        </div>
        <div class="window-body delete-confirm-dialog__body">
          <p>Delete this message?</p>
          <div class="delete-confirm-dialog__actions">
            <button class="btn-icon" phx-click="confirm_delete" data-testid="confirm-delete-btn">
              <Icons.icon_btn_ok class="btn-icon__svg" /> Confirm
            </button>
            <button class="btn-icon" phx-click="cancel_delete" data-testid="cancel-delete-btn">
              <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

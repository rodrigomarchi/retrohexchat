defmodule RetroHexChatWeb.Components.DeleteConfirmDialog do
  @moduledoc """
  Delete confirmation dialog: "Apagar esta mensagem?" with Confirmar/Cancelar.
  """
  use Phoenix.Component

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
          <div class="title-bar-text">Confirmar</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cancel_delete"></button>
          </div>
        </div>
        <div class="window-body delete-confirm-dialog__body">
          <p>Apagar esta mensagem?</p>
          <div class="delete-confirm-dialog__actions">
            <button phx-click="confirm_delete" data-testid="confirm-delete-btn">
              Confirmar
            </button>
            <button phx-click="cancel_delete" data-testid="cancel-delete-btn">
              Cancelar
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

defmodule RetroHexChatWeb.Components.PasteConfirmDialog do
  @moduledoc """
  Confirmation dialog for multi-line paste operations.
  Shows line count, flood warning, and send/cancel buttons.
  """
  use Phoenix.Component

  attr :visible, :boolean, default: false
  attr :line_count, :integer, default: 0
  attr :flood_warning, :boolean, default: false
  attr :send_disabled, :boolean, default: false

  @spec paste_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def paste_confirm_dialog(assigns) do
    ~H"""
    <div :if={@visible} class="window paste-dialog" data-testid="paste-dialog">
      <div class="title-bar">
        <div class="title-bar-text">Paste Confirmation</div>
        <div class="title-bar-controls">
          <button aria-label="Close" phx-click="paste_cancel"></button>
        </div>
      </div>
      <div class="window-body dialog-body">
        <p>You are about to send <strong>{@line_count} lines</strong>.</p>

        <p :if={@flood_warning && !@send_disabled} class="paste-flood-warning">
          Warning: Sending many lines may be considered flood. Proceed with caution.
        </p>

        <p :if={@send_disabled} class="paste-flood-warning">
          Too many lines (max 100). Please use a pastebin service instead.
        </p>

        <div class="dialog-buttons u-mt-12">
          <button phx-click="paste_send" disabled={@send_disabled} data-testid="paste-send-btn">
            Send All
          </button>
          <button phx-click="paste_cancel" data-testid="paste-cancel-btn">Cancel</button>
        </div>
      </div>
    </div>
    """
  end
end

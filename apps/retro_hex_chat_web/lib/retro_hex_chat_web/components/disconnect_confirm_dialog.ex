defmodule RetroHexChatWeb.Components.DisconnectConfirmDialog do
  @moduledoc """
  Disconnect confirmation dialog: "Are you sure you want to disconnect?"
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :visible, :boolean, default: false

  @spec disconnect_confirm_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def disconnect_confirm_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      phx-window-keydown="cancel_disconnect"
      phx-key="Escape"
      data-testid="disconnect-confirm-dialog"
    >
      <div class="window dialog-window--generic">
        <div class="title-bar">
          <Icons.icon_btn_disconnect class="title-bar-icon" />
          <div class="title-bar-text">Disconnect</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click="cancel_disconnect"></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          <div class="u-flex u-items-center u-gap-12">
            <Icons.icon_warning class="dialog-body-icon" />
            <p>Are you sure you want to disconnect?</p>
          </div>
          <div class="dialog-buttons dialog-buttons--gap-8">
            <button
              class="btn-icon"
              phx-click="confirm_disconnect"
              data-testid="confirm-disconnect-btn"
            >
              <Icons.icon_btn_disconnect class="btn-icon__svg" /> Disconnect
            </button>
            <button
              class="btn-icon"
              phx-click="cancel_disconnect"
              data-testid="cancel-disconnect-btn"
            >
              <Icons.icon_btn_cancel class="btn-icon__svg" /> Cancel
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

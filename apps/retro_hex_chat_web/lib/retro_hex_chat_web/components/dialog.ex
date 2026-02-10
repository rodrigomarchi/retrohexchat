defmodule RetroHexChatWeb.Components.Dialog do
  @moduledoc """
  Reusable modal dialog using 98.css window styling.
  Supports info (default) and confirm modes.
  """
  use Phoenix.Component

  attr :mode, :string, default: "info"
  attr :on_close, :string, default: "close_dialog"
  attr :on_confirm, :string, default: "confirm_dialog"
  attr :title, :string, required: true
  attr :visible, :boolean, default: false
  slot :inner_block, required: true

  @spec dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      style="position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; z-index: 200; background: rgba(0,0,0,0.5);"
    >
      <div class="window" style="min-width: 300px; max-width: 500px;">
        <div class="title-bar">
          <div class="title-bar-text">{@title}</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click={@on_close}></button>
          </div>
        </div>
        <div class="window-body" style="padding: 12px;">
          {render_slot(@inner_block)}
          <div
            :if={@mode == "confirm"}
            class="dialog-buttons"
            style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 12px;"
          >
            <button type="button" phx-click={@on_confirm}>OK</button>
            <button type="button" phx-click={@on_close}>Cancel</button>
          </div>
          <div
            :if={@mode == "info"}
            class="dialog-buttons"
            style="display: flex; justify-content: flex-end; margin-top: 12px;"
          >
            <button type="button" phx-click={@on_close}>OK</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

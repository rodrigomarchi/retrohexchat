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
      class="dialog-overlay dialog-overlay--dark"
    >
      <div class="window dialog-window--generic">
        <div class="title-bar">
          <div class="title-bar-text">{@title}</div>
          <div class="title-bar-controls">
            <button aria-label="Close" phx-click={@on_close}></button>
          </div>
        </div>
        <div class="window-body dialog-body">
          {render_slot(@inner_block)}
          <div
            :if={@mode == "confirm"}
            class="dialog-buttons dialog-buttons--gap-8 u-mt-12"
          >
            <button type="button" phx-click={@on_confirm}>OK</button>
            <button type="button" phx-click={@on_close}>Cancel</button>
          </div>
          <div
            :if={@mode == "info"}
            class="dialog-buttons u-mt-12"
          >
            <button type="button" phx-click={@on_close}>OK</button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

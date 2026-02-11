defmodule RetroHexChatWeb.Components.StatusWindow do
  @moduledoc """
  98.css styled Status window for system messages (online/offline notifications, renames, etc.).
  Always rendered — no visibility toggle or close button.

  Accepts an `inner_block` slot so the parent LiveView can render its stream content inline.
  """
  use Phoenix.Component

  slot :inner_block, required: true

  @spec status_window(map()) :: Phoenix.LiveView.Rendered.t()
  def status_window(assigns) do
    ~H"""
    <div class="status-window" data-testid="status-window" style="width: 100%; height: 100%;">
      <div class="window" style="height: 100%; display: flex; flex-direction: column;">
        <div class="title-bar">
          <div class="title-bar-text">Status</div>
        </div>
        <div
          class="window-body"
          style="flex: 1; overflow-y: auto; padding: 4px; font-size: 12px; background: #000; color: #c0c0c0;"
        >
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @type_colors %{
    notify_online: "#2ecc71",
    notify_offline: "#95a5a6",
    notify_rename: "#00bcd4",
    system: "#c0c0c0"
  }

  @spec status_message_style(atom()) :: String.t()
  def status_message_style(type) do
    color = Map.get(@type_colors, type, "#c0c0c0")
    "color: #{color}; padding: 1px 0;"
  end

  @spec format_time(DateTime.t() | any()) :: String.t()
  def format_time(%DateTime{} = dt) do
    Calendar.strftime(dt, "%H:%M")
  end

  def format_time(_), do: "--:--"
end

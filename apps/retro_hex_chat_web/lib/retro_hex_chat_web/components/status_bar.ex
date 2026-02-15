defmodule RetroHexChatWeb.Components.StatusBar do
  @moduledoc """
  Status bar with three sections: channel info, connection state, lag/clock/mute.
  """
  use Phoenix.Component

  attr :nickname, :string, required: true
  attr :channel, :string, default: nil
  attr :user_count, :integer, default: 0
  attr :connection_state, :atom, default: :connected
  attr :lag_ms, :integer, default: nil
  attr :lag_status, :atom, default: :normal
  attr :muted, :boolean, default: false

  @spec status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def status_bar(assigns) do
    ~H"""
    <div class="status-bar">
      <p class="status-bar-field status-bar-section--left" data-testid="status-channel">
        {@channel || "No channel"} — {@user_count} users
      </p>
      <p
        class={"status-bar-field status-bar-section--center status-bar-connection--#{@connection_state}"}
        data-testid="status-connection"
      >
        {connection_indicator(@connection_state)} {connection_text(@connection_state)}
      </p>
      <p class="status-bar-field status-bar-section--right" data-testid="status-right">
        <span
          id="lag-display"
          class={"status-bar-lag status-bar-lag--#{@lag_status}"}
          phx-hook="LagHook"
          data-testid="status-lag"
        >
          Lag: {lag_text(@lag_ms, @lag_status)}
        </span>
        <span class="status-bar-separator">|</span>
        <span id="clock-display" phx-hook="ClockHook" data-testid="status-clock">--:--</span>
        <span class="status-bar-separator">|</span>
        <span
          class="mute-toggle status-bar-clickable"
          data-testid="mute-toggle"
          phx-click="toggle_mute"
        >
          {if @muted, do: "[MUTE]", else: "[SND]"}
        </span>
      </p>
    </div>
    """
  end

  @spec connection_indicator(atom()) :: String.t()
  defp connection_indicator(:connected), do: "●"
  defp connection_indicator(:connecting), do: "◌"
  defp connection_indicator(:disconnected), do: "●"
  defp connection_indicator(:reconnecting), do: "↻"
  defp connection_indicator(_), do: "●"

  @spec connection_text(atom()) :: String.t()
  defp connection_text(:connected), do: "Connected"
  defp connection_text(:connecting), do: "Connecting..."
  defp connection_text(:disconnected), do: "Disconnected"
  defp connection_text(:reconnecting), do: "Reconnecting..."
  defp connection_text(_), do: "Connected"

  @spec lag_text(non_neg_integer() | nil, atom()) :: String.t()
  defp lag_text(nil, :timeout), do: "?"
  defp lag_text(nil, _status), do: "—"
  defp lag_text(ms, _status), do: "#{ms}ms"
end

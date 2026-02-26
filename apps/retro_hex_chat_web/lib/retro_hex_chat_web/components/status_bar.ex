defmodule RetroHexChatWeb.Components.StatusBar do
  @moduledoc """
  Status bar with three sections: channel info, connection state, lag/clock/mute.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  attr :nickname, :string, required: true
  attr :channel, :string, default: nil
  attr :user_count, :integer, default: 0
  attr :tab_type, :atom, default: :channel
  attr :lag_ms, :integer, default: nil
  attr :lag_status, :atom, default: :normal
  attr :muted, :boolean, default: false
  attr :timezone, :string, default: "Etc/UTC"

  @spec status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def status_bar(assigns) do
    ~H"""
    <div class="status-bar">
      <p class="status-bar-field status-bar-section--left">
        <Icons.icon_status_user class="status-bar-icon" />
        <span class="status-bar-nick" data-testid="status-nick">{@nickname}</span>
        <span class="status-bar-separator">|</span>
        <Icons.icon_tab_channel :if={@tab_type == :channel} class="status-bar-icon" />
        <Icons.icon_tab_pm :if={@tab_type == :pm} class="status-bar-icon" />
        <span class="status-bar-channel" data-testid="status-channel">
          {@channel || "No channel"}
        </span>
        <span :if={@tab_type == :channel} data-testid="status-users">({@user_count})</span>
        <span class="status-bar-separator">|</span>
        <span
          class="status-bar-connection--connected"
          data-testid="status-connection"
        >
          ● On
        </span>
        <span class="status-bar-separator">|</span>
        <Icons.icon_status_signal class="status-bar-icon" />
        <span
          id="lag-display"
          class={"status-bar-lag status-bar-lag--#{@lag_status}"}
          phx-hook="LagHook"
          data-testid="status-lag"
        >
          Lag: {lag_text(@lag_ms, @lag_status)}
        </span>
        <span class="status-bar-separator">|</span>
        <Icons.icon_clock class="status-bar-icon" />
        <span id="clock-display" phx-hook="ClockHook" data-testid="status-clock">--:--</span>
        <span class="status-bar-tz" data-testid="status-timezone">
          {RetroHexChatWeb.Timezone.format_utc_offset(@timezone)}
        </span>
        <span class="status-bar-separator">|</span>
        <span
          class="mute-toggle status-bar-clickable"
          data-testid="mute-toggle"
          phx-click="toggle_mute"
        >
          <Icons.icon_dialog_sound :if={!@muted} class="status-bar-icon" />
          <Icons.icon_mute :if={@muted} class="status-bar-icon" />
        </span>
      </p>
    </div>
    """
  end

  @spec lag_text(non_neg_integer() | nil, atom()) :: String.t()
  defp lag_text(nil, :timeout), do: "?"
  defp lag_text(nil, _status), do: "—"
  defp lag_text(ms, _status), do: "#{ms}ms"
end

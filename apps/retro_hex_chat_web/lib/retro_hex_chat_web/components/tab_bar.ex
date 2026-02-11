defmodule RetroHexChatWeb.Components.TabBar do
  @moduledoc """
  Horizontal tab bar with Status, Channel, and PM tabs.
  Mirrors treebar navigation with quick horizontal access.
  """
  use Phoenix.Component

  attr :channels, :list, default: []
  attr :pm_conversations, :list, default: []
  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :show_status_tab, :boolean, default: false
  attr :unread_channels, :list, default: []
  attr :highlight_channels, :list, default: []

  @spec tab_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def tab_bar(assigns) do
    ~H"""
    <div class="tab-bar" data-testid="tab-bar">
      <div
        class={status_tab_class(@show_status_tab)}
        phx-click="switch_to_status"
        data-testid="tab-status"
      >
        <span class="tab-label">Status</span>
      </div>
      <div
        :for={channel <- @channels}
        class={
          channel_tab_class(
            channel,
            @active_channel,
            @show_status_tab,
            @unread_channels,
            @highlight_channels
          )
        }
        data-testid={"tab-#{channel}"}
      >
        <span class="tab-label" phx-click="switch_channel" phx-value-channel={channel}>
          {channel}
        </span>
        <button
          type="button"
          class="tab-close"
          phx-click="close_channel_tab"
          phx-value-channel={channel}
          data-testid={"tab-close-#{channel}"}
          title={"Close #{channel}"}
        >
          ×
        </button>
      </div>
      <div
        :for={pm <- @pm_conversations}
        class={pm_tab_class(pm, @active_pm, @show_status_tab, @unread_channels)}
        data-testid={"tab-pm-#{pm}"}
      >
        <span class="tab-label" phx-click="switch_pm" phx-value-nickname={pm}>{pm}</span>
        <button
          type="button"
          class="tab-close"
          phx-click="close_pm_tab"
          phx-value-nickname={pm}
          data-testid={"tab-close-pm-#{pm}"}
          title={"Close #{pm}"}
        >
          ×
        </button>
      </div>
    </div>
    """
  end

  @spec status_tab_class(boolean()) :: String.t()
  defp status_tab_class(active) do
    base = "tab-item tab-item--status"
    if active, do: "#{base} tab-active", else: base
  end

  @spec channel_tab_class(String.t(), String.t() | nil, boolean(), list(), list()) :: String.t()
  defp channel_tab_class(channel, active, status_active, unread, highlight) do
    classes = ["tab-item"]
    active_match = channel == active and not status_active
    classes = if active_match, do: ["tab-active" | classes], else: classes
    classes = if channel in unread, do: ["tab-unread" | classes], else: classes
    classes = if channel in highlight, do: ["tab-highlight" | classes], else: classes
    Enum.join(Enum.reverse(classes), " ")
  end

  @spec pm_tab_class(String.t(), String.t() | nil, boolean(), list()) :: String.t()
  defp pm_tab_class(pm, active_pm, status_active, unread) do
    classes = ["tab-item", "tab-item--pm"]
    active_match = pm == active_pm and not status_active
    classes = if active_match, do: ["tab-active" | classes], else: classes
    classes = if "pm:#{pm}" in unread, do: ["tab-unread" | classes], else: classes
    Enum.join(Enum.reverse(classes), " ")
  end
end

defmodule RetroHexChatWeb.Components.TabBar do
  @moduledoc """
  Horizontal tab bar with Status, Channel, and PM tabs.
  Mirrors treebar navigation with quick horizontal access.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.UnreadTracker
  alias RetroHexChatWeb.Icons

  attr :channels, :list, default: []
  attr :pm_conversations, :list, default: []
  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :show_status_tab, :boolean, default: false
  attr :unread_counts, :map, default: %{}
  attr :highlight_channels, :list, default: []
  attr :status_unread, :boolean, default: false

  @spec tab_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def tab_bar(assigns) do
    ~H"""
    <div class="tab-bar" data-testid="tab-bar">
      <div
        class={status_tab_class(@show_status_tab, @status_unread)}
        phx-click="switch_to_status"
        data-testid="tab-status"
      >
        <Icons.icon_tab_status class="tab-item-icon" />
        <span class="tab-label">Status</span>
      </div>
      <div
        :for={channel <- @channels}
        class={
          channel_tab_class(
            channel,
            @active_channel,
            @show_status_tab,
            @unread_counts,
            @highlight_channels
          )
        }
        data-testid={"tab-#{channel}"}
      >
        <Icons.icon_tab_channel class="tab-item-icon" />
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
        class={pm_tab_class(pm, @active_pm, @show_status_tab, @unread_counts)}
        data-testid={"tab-pm-#{pm}"}
      >
        <Icons.icon_tab_pm class="tab-item-icon" />
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

  @spec status_tab_class(boolean(), boolean()) :: String.t()
  defp status_tab_class(active, unread) do
    classes = ["tab-item", "tab-item--status"]
    classes = if active, do: ["tab-active" | classes], else: classes
    classes = if unread and not active, do: ["tab-unread" | classes], else: classes
    Enum.join(Enum.reverse(classes), " ")
  end

  @spec channel_tab_class(
          String.t(),
          String.t() | nil,
          boolean(),
          UnreadTracker.counts(),
          list()
        ) :: String.t()
  defp channel_tab_class(channel, active, status_active, unread_counts, highlight) do
    classes = ["tab-item"]
    active_match = channel == active and not status_active
    classes = if active_match, do: ["tab-active" | classes], else: classes

    classes =
      if UnreadTracker.unread?(unread_counts, channel),
        do: ["tab-unread" | classes],
        else: classes

    classes = if channel in highlight, do: ["tab-highlight" | classes], else: classes
    Enum.join(Enum.reverse(classes), " ")
  end

  @spec pm_tab_class(String.t(), String.t() | nil, boolean(), UnreadTracker.counts()) ::
          String.t()
  defp pm_tab_class(pm, active_pm, status_active, unread_counts) do
    classes = ["tab-item", "tab-item--pm"]
    active_match = pm == active_pm and not status_active
    classes = if active_match, do: ["tab-active" | classes], else: classes

    classes =
      if UnreadTracker.unread?(unread_counts, "pm:#{pm}"),
        do: ["tab-unread" | classes],
        else: classes

    Enum.join(Enum.reverse(classes), " ")
  end
end

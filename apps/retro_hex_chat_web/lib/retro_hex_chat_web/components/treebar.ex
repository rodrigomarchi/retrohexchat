defmodule RetroHexChatWeb.Components.Treebar do
  @moduledoc """
  Treebar component with Services/Channels/Private sections.
  Active channel highlighted, unread channels bold with numeric badges.
  Supports 6 visual states: normal, unread, highlight, active, muted, disconnected.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.UnreadTracker

  attr :channels, :list, default: []
  attr :active_channel, :string, default: nil
  attr :unread_counts, :map, default: %{}
  attr :highlight_channels, :list, default: []
  attr :flash_channels, :list, default: []
  attr :muted_channels, :list, default: []
  attr :disconnected_channels, :list, default: []
  attr :pm_conversations, :list, default: []
  attr :active_pm, :string, default: nil

  @spec treebar(map()) :: Phoenix.LiveView.Rendered.t()
  def treebar(assigns) do
    ~H"""
    <div class="treebar" id="treebar" phx-hook="TreebarHook">
      <div class="treebar-header">
        <span class="treebar-header-title">Conversations</span>
        <button
          type="button"
          class="treebar-close"
          title="Hide channel list"
          phx-click="toggle_treebar"
          aria-label="Hide channel list"
        >
          <svg viewBox="0 0 8 7" width="8" height="7" fill="currentColor">
            <polygon points="0,0 8,3.5 0,7" />
          </svg>
        </button>
      </div>
      <div
        :if={@channels == [] and @pm_conversations == []}
        class="empty-state treebar-empty-state"
        data-testid="treebar-empty-state"
      >
        <p>Nenhum canal — /join #canal para começar</p>
        <button type="button" class="empty-state-action" phx-click="open_channel_list">
          Explorar canais
        </button>
      </div>
      <ul :if={@channels != [] or @pm_conversations != []} class="tree-view">
        <li>
          <details open>
            <summary>Channels</summary>
            <ul>
              <li
                :for={channel <- @channels}
                class={
                  treebar_item_class(
                    channel,
                    @active_channel,
                    @unread_counts,
                    @highlight_channels,
                    @flash_channels,
                    @muted_channels,
                    @disconnected_channels
                  )
                }
                data-testid={"channel-#{channel}"}
                data-channel={channel}
                phx-click="switch_channel"
                phx-value-channel={channel}
                phx-dblclick="open_channel_central"
                phx-value-cc_channel={channel}
              >
                <span :if={channel in @disconnected_channels}>⚡</span>
                {channel}
                <.badge
                  :if={UnreadTracker.unread?(@unread_counts, channel)}
                  count={UnreadTracker.get_count(@unread_counts, channel)}
                  highlight={channel in @highlight_channels}
                />
              </li>
            </ul>
          </details>
        </li>
        <li>
          <details open>
            <summary>Private</summary>
            <ul>
              <li
                :for={pm <- @pm_conversations}
                class={
                  pm_item_class(
                    pm,
                    @active_pm,
                    @unread_counts,
                    @flash_channels
                  )
                }
                data-testid={"pm-#{pm}"}
                phx-click="switch_pm"
                phx-value-nickname={pm}
              >
                {pm}
                <.badge
                  :if={UnreadTracker.unread?(@unread_counts, "pm:#{pm}")}
                  count={UnreadTracker.get_count(@unread_counts, "pm:#{pm}")}
                  highlight={false}
                />
              </li>
            </ul>
          </details>
        </li>
      </ul>
    </div>
    """
  end

  attr :count, :integer, required: true
  attr :highlight, :boolean, default: false

  defp badge(assigns) do
    ~H"""
    <span class={badge_class(@highlight)}>{UnreadTracker.display_count(@count)}</span>
    """
  end

  @spec badge_class(boolean()) :: String.t()
  defp badge_class(true), do: "treebar-badge treebar-badge--highlight"
  defp badge_class(false), do: "treebar-badge"

  @spec treebar_item_class(
          String.t(),
          String.t() | nil,
          UnreadTracker.counts(),
          list(String.t()),
          list(String.t()),
          list(String.t()),
          list(String.t())
        ) :: String.t()
  defp treebar_item_class(channel, active, unread_counts, highlight, flash, muted, disconnected) do
    classes = []
    classes = if channel == active, do: ["tree-active" | classes], else: classes

    classes =
      if UnreadTracker.unread?(unread_counts, channel),
        do: ["tree-unread" | classes],
        else: classes

    classes =
      if channel in highlight or channel in flash,
        do: ["tree-highlight" | classes],
        else: classes

    classes = if channel in muted, do: ["tree-muted" | classes], else: classes
    classes = if channel in disconnected, do: ["tree-disconnected" | classes], else: classes

    Enum.join(classes, " ")
  end

  @spec pm_item_class(String.t(), String.t() | nil, UnreadTracker.counts(), list(String.t())) ::
          String.t()
  defp pm_item_class(pm, active_pm, unread_counts, flash) do
    classes = []
    classes = if pm == active_pm, do: ["tree-active" | classes], else: classes

    classes =
      if UnreadTracker.unread?(unread_counts, "pm:#{pm}"),
        do: ["tree-unread" | classes],
        else: classes

    classes = if "pm:#{pm}" in flash, do: ["tree-highlight" | classes], else: classes
    Enum.join(classes, " ")
  end
end

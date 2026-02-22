defmodule RetroHexChatWeb.Components.Treebar do
  @moduledoc """
  Treebar component with Channels/Private sections plus inline user list.
  The active channel is pinned to the top of the Channels section with its
  users expanded below it, sorted by role priority (owner > operator >
  half_op > voiced > regular), alphabetically within each role.
  Supports 6 visual states: normal, unread, highlight, active, muted, disconnected.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.UnreadTracker
  alias RetroHexChatWeb.Icons

  @role_priority %{owner: 0, operator: 1, half_operator: 2, voiced: 3, regular: 4}

  attr :channels, :list, default: []
  attr :active_channel, :string, default: nil
  attr :unread_counts, :map, default: %{}
  attr :highlight_channels, :list, default: []
  attr :flash_channels, :list, default: []
  attr :muted_channels, :list, default: []
  attr :disconnected_channels, :list, default: []
  attr :pm_conversations, :list, default: []
  attr :active_pm, :string, default: nil
  attr :channel_users, :list, default: []
  attr :nick_color_fn, :any, default: nil

  @spec treebar(map()) :: Phoenix.LiveView.Rendered.t()
  def treebar(assigns) do
    sorted_users = sort_users_by_role(assigns.channel_users)
    other_channels = Enum.reject(assigns.channels, &(&1 == assigns.active_channel))

    assigns =
      assigns
      |> assign(:sorted_users, sorted_users)
      |> assign(:other_channels, other_channels)

    ~H"""
    <div class="treebar" id="treebar" phx-hook="TreebarHook">
      <div class="sidebar-tab-bar sidebar-tab-bar--left">
        <div class="tab-item tab-active">
          <Icons.icon_tab_conversations class="treebar-icon" />
          <span class="tab-label">Conversations</span>
          <button
            type="button"
            class="tab-close"
            phx-click="toggle_treebar"
            title="Hide channel list"
            aria-label="Hide channel list"
          >
            ×
          </button>
        </div>
      </div>
      <div
        :if={@channels == [] and @pm_conversations == []}
        class="empty-state treebar-empty-state"
        data-testid="treebar-empty-state"
      >
        <p>No channels — /join #channel to get started</p>
        <button type="button" class="empty-state-action" phx-click="open_channel_list">
          Browse channels
        </button>
      </div>
      <ul :if={@channels != [] or @pm_conversations != []} class="tree-view">
        <li>
          <details open>
            <summary><Icons.icon_tab_channel class="treebar-icon" /> Channels</summary>
            <ul>
              <.channel_item
                :if={@active_channel && @active_channel in @channels}
                channel={@active_channel}
                active_channel={@active_channel}
                unread_counts={@unread_counts}
                highlight_channels={@highlight_channels}
                flash_channels={@flash_channels}
                muted_channels={@muted_channels}
                disconnected_channels={@disconnected_channels}
                channel_users={@sorted_users}
                nick_color_fn={@nick_color_fn}
              />
              <.channel_item
                :for={channel <- @other_channels}
                channel={channel}
                active_channel={@active_channel}
                unread_counts={@unread_counts}
                highlight_channels={@highlight_channels}
                flash_channels={@flash_channels}
                muted_channels={@muted_channels}
                disconnected_channels={@disconnected_channels}
                channel_users={[]}
                nick_color_fn={nil}
              />
            </ul>
          </details>
        </li>
        <li>
          <details open>
            <summary><Icons.icon_tab_pm class="treebar-icon" /> Private</summary>
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
                <Icons.icon_tab_pm class="treebar-icon" />
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

  attr :channel, :string, required: true
  attr :active_channel, :string, default: nil
  attr :unread_counts, :map, required: true
  attr :highlight_channels, :list, required: true
  attr :flash_channels, :list, required: true
  attr :muted_channels, :list, required: true
  attr :disconnected_channels, :list, required: true
  attr :channel_users, :list, default: []
  attr :nick_color_fn, :any, default: nil

  defp channel_item(assigns) do
    is_active = assigns.channel == assigns.active_channel

    assigns =
      assigns
      |> assign(:is_active, is_active)
      |> assign(
        :item_class,
        treebar_item_class(
          assigns.channel,
          assigns.active_channel,
          assigns.unread_counts,
          assigns.highlight_channels,
          assigns.flash_channels,
          assigns.muted_channels,
          assigns.disconnected_channels
        )
      )

    ~H"""
    <li
      class={@item_class}
      data-testid={"channel-#{@channel}"}
      data-channel={@channel}
      phx-click="switch_channel"
      phx-value-channel={@channel}
      phx-dblclick="open_channel_central"
      phx-value-cc_channel={@channel}
    >
      <span :if={@channel in @disconnected_channels}>⚡</span>
      <Icons.icon_tab_channel class="treebar-icon" />
      {@channel}
      <span :if={@is_active && @channel_users != []} class="treebar-user-count">
        ({length(@channel_users)})
      </span>
      <.badge
        :if={UnreadTracker.unread?(@unread_counts, @channel)}
        count={UnreadTracker.get_count(@unread_counts, @channel)}
        highlight={@channel in @highlight_channels}
      />
    </li>
    <li :if={@is_active && @channel_users != []} class="treebar-users-container">
      <ul class="treebar-users" data-testid="treebar-users">
        <li
          :for={user <- @channel_users}
          class={user_item_class(user)}
          phx-click="nick_right_click"
          phx-value-nick={user.nickname}
          data-nick={user.nickname}
          style={nick_style(@nick_color_fn, user.nickname)}
        >
          <.role_icon role={user.role} /> {user.nickname}
        </li>
      </ul>
    </li>
    """
  end

  attr :count, :integer, required: true
  attr :highlight, :boolean, default: false

  defp badge(assigns) do
    ~H"""
    <span class={badge_class(@highlight)}>{UnreadTracker.display_count(@count)}</span>
    """
  end

  attr :role, :atom, required: true

  defp role_icon(%{role: :owner} = assigns) do
    ~H"""
    <Icons.icon_role_owner class="nick-icon" />
    """
  end

  defp role_icon(%{role: :operator} = assigns) do
    ~H"""
    <Icons.icon_role_operator class="nick-icon" />
    """
  end

  defp role_icon(%{role: :half_operator} = assigns) do
    ~H"""
    <Icons.icon_role_halfop class="nick-icon" />
    """
  end

  defp role_icon(%{role: :voiced} = assigns) do
    ~H"""
    <Icons.icon_role_voiced class="nick-icon" />
    """
  end

  defp role_icon(%{role: _} = assigns) do
    ~H"""
    <Icons.icon_role_regular class="nick-icon" />
    """
  end

  @spec badge_class(boolean()) :: String.t()
  defp badge_class(true), do: "treebar-badge treebar-badge--highlight"
  defp badge_class(false), do: "treebar-badge"

  @spec nick_style((String.t() -> String.t()) | nil, String.t()) :: String.t()
  defp nick_style(nil, _nickname), do: ""
  defp nick_style(color_fn, nickname), do: "color: #{color_fn.(nickname)};"

  @spec user_item_class(map()) :: String.t()
  defp user_item_class(user) do
    role_class = role_css_class(user.role)
    if user.away, do: "#{role_class} nick-away", else: role_class
  end

  @spec role_css_class(atom()) :: String.t()
  defp role_css_class(:owner), do: "nick-owner"
  defp role_css_class(:operator), do: "nick-operator"
  defp role_css_class(:half_operator), do: "nick-halfop"
  defp role_css_class(:voiced), do: "nick-voiced"
  defp role_css_class(_), do: "nick-regular"

  @spec sort_users_by_role(list(map())) :: list(map())
  defp sort_users_by_role(users) do
    Enum.sort_by(users, fn user ->
      {Map.get(@role_priority, user.role, 99), user.nickname}
    end)
  end

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

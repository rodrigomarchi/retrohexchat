defmodule RetroHexChatWeb.Components.Conversations do
  @moduledoc """
  Conversations sidebar component with Channels/Private sections plus inline user list.
  The active channel is pinned to the top of the Channels section with its
  users expanded below it, sorted by role priority (owner > operator >
  half_op > voiced > regular), alphabetically within each role.
  Supports 6 visual states: normal, unread, highlight, active, muted, disconnected.
  """
  use Phoenix.Component

  alias RetroHexChat.Chat.UnreadTracker
  alias RetroHexChatWeb.Icons

  @role_priority %{owner: 0, operator: 1, half_operator: 2, voiced: 3, regular: 4, bot: 5}

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
  attr :channel_user_counts, :map, default: %{}
  attr :popular_channels, :list, default: []
  attr :sections, :map, default: %{channels: true, pms: true, popular: false}

  @spec conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations(assigns) do
    sorted_users = sort_users_by_role(assigns.channel_users)
    other_channels = Enum.reject(assigns.channels, &(&1 == assigns.active_channel))

    assigns =
      assigns
      |> assign(:sorted_users, sorted_users)
      |> assign(:other_channels, other_channels)

    ~H"""
    <div class="conversations" id="conversations" phx-hook="ConversationsHook">
      <div class="sidebar-tab-bar sidebar-tab-bar--left">
        <div class="tab-item tab-active">
          <Icons.icon_tab_conversations class="conversations-icon" />
          <span class="tab-label">Conversations</span>
          <button
            type="button"
            class="tab-close"
            phx-click="toggle_conversations"
            title="Hide channel list"
            aria-label="Hide channel list"
          >
            ×
          </button>
        </div>
      </div>
      <div
        :if={@channels == [] and @pm_conversations == []}
        class="empty-state conversations-empty-state"
        data-testid="conversations-empty-state"
      >
        <p>No channels — /join #channel to get started</p>
        <button type="button" class="empty-state-action" phx-click="open_channel_list">
          Browse channels
        </button>
      </div>
      <div
        :if={@channels != [] or @pm_conversations != []}
        class="conversations-sections"
      >
        <.section_header
          label="MY CHANNELS"
          section="channels"
          expanded={@sections.channels}
        />
        <ul :if={@sections.channels} class="conversations-list">
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
            channel_user_counts={@channel_user_counts}
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
            channel_user_counts={@channel_user_counts}
          />
        </ul>

        <.section_header
          label="PRIVATE MESSAGES"
          section="pms"
          expanded={@sections.pms}
        />
        <ul :if={@sections.pms} class="conversations-list">
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
            <Icons.icon_tab_pm class="conversations-icon" />
            {pm}
            <.badge
              :if={UnreadTracker.unread?(@unread_counts, "pm:#{pm}")}
              count={UnreadTracker.get_count(@unread_counts, "pm:#{pm}")}
              highlight={false}
            />
          </li>
        </ul>

        <.section_header
          label="POPULAR CHANNELS"
          section="popular"
          expanded={@sections.popular}
        />
        <ul :if={@sections.popular} class="conversations-list">
          <li
            :for={ch <- @popular_channels}
            class="conversations-popular-item"
            data-testid={"popular-#{ch.name}"}
          >
            <Icons.icon_tab_channel class="conversations-icon" />
            <span class="conversations-popular-name">{ch.name}</span>
            <span class="conversations-popular-count">({ch.user_count})</span>
            <button
              type="button"
              class="conversations-join-btn"
              phx-click="conversations_join_popular"
              phx-value-channel={ch.name}
              title={"Join #{ch.name}"}
            >
              <Icons.icon_btn_add class="conversations-join-icon" />
            </button>
          </li>
          <li class="conversations-browse-all">
            <button
              type="button"
              class="conversations-browse-all-btn"
              phx-click="conversations_browse_all"
            >
              <Icons.icon_dialog_channel_list class="conversations-browse-icon" />
              <span>Browse All Channels...</span>
            </button>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :section, :string, required: true
  attr :expanded, :boolean, required: true

  defp section_header(assigns) do
    ~H"""
    <div
      class="conversations-section-header"
      phx-click="conversations_toggle_section"
      phx-value-section={@section}
      data-testid={"conversations-section-#{@section}"}
    >
      <span class="conversations-section-arrow">{if @expanded, do: "▾", else: "▸"}</span>
      {@label}
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
  attr :channel_user_counts, :map, default: %{}

  defp channel_item(assigns) do
    is_active = assigns.channel == assigns.active_channel
    user_count = Map.get(assigns.channel_user_counts, assigns.channel)

    assigns =
      assigns
      |> assign(:is_active, is_active)
      |> assign(:user_count, user_count)
      |> assign(
        :item_class,
        conversations_item_class(
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
      <Icons.icon_tab_channel class="conversations-icon" />
      {@channel}
      <span :if={@user_count} class="conversations-user-count">
        ({@user_count})
      </span>
      <.badge
        :if={UnreadTracker.unread?(@unread_counts, @channel)}
        count={UnreadTracker.get_count(@unread_counts, @channel)}
        highlight={@channel in @highlight_channels}
      />
    </li>
    <li :if={@is_active && @channel_users != []} class="conversations-users-container">
      <ul class="conversations-users" data-testid="conversations-users">
        <li
          :for={user <- @channel_users}
          class={[user_item_class(user), @nick_color_fn && @nick_color_fn.(user.nickname)]}
          phx-click="nick_right_click"
          phx-value-nick={user.nickname}
          data-nick={user.nickname}
        >
          <Icons.icon_role_regular class="nick-icon" />
          {user.nickname}
          <.role_badge role={user.role} />
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

  defp role_badge(%{role: :owner} = assigns) do
    ~H"""
    <Icons.icon_role_owner class="nick-badge" />
    """
  end

  defp role_badge(%{role: :operator} = assigns) do
    ~H"""
    <Icons.icon_role_operator class="nick-badge" />
    """
  end

  defp role_badge(%{role: :half_operator} = assigns) do
    ~H"""
    <Icons.icon_role_halfop class="nick-badge" />
    """
  end

  defp role_badge(%{role: :voiced} = assigns) do
    ~H"""
    <Icons.icon_role_voiced class="nick-badge" />
    """
  end

  defp role_badge(%{role: :bot} = assigns) do
    ~H"""
    <span class="nick-badge nick-icon--bot" title="Bot">&#9881;</span>
    """
  end

  defp role_badge(%{role: _} = assigns) do
    ~H""
  end

  @spec badge_class(boolean()) :: String.t()
  defp badge_class(true), do: "conversations-badge conversations-badge--highlight"
  defp badge_class(false), do: "conversations-badge"

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

  @spec conversations_item_class(
          String.t(),
          String.t() | nil,
          UnreadTracker.counts(),
          list(String.t()),
          list(String.t()),
          list(String.t()),
          list(String.t())
        ) :: String.t()
  defp conversations_item_class(
         channel,
         active,
         unread_counts,
         highlight,
         flash,
         muted,
         disconnected
       ) do
    classes = []
    classes = if channel == active, do: ["conversations-active" | classes], else: classes

    classes =
      if UnreadTracker.unread?(unread_counts, channel),
        do: ["conversations-unread" | classes],
        else: classes

    classes =
      if channel in highlight or channel in flash,
        do: ["conversations-highlight" | classes],
        else: classes

    classes = if channel in muted, do: ["conversations-muted" | classes], else: classes

    classes =
      if channel in disconnected, do: ["conversations-disconnected" | classes], else: classes

    Enum.join(classes, " ")
  end

  @spec pm_item_class(String.t(), String.t() | nil, UnreadTracker.counts(), list(String.t())) ::
          String.t()
  defp pm_item_class(pm, active_pm, unread_counts, flash) do
    classes = []
    classes = if pm == active_pm, do: ["conversations-active" | classes], else: classes

    classes =
      if UnreadTracker.unread?(unread_counts, "pm:#{pm}"),
        do: ["conversations-unread" | classes],
        else: classes

    classes = if "pm:#{pm}" in flash, do: ["conversations-highlight" | classes], else: classes
    Enum.join(classes, " ")
  end
end

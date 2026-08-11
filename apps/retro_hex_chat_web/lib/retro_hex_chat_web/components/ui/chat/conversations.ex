defmodule RetroHexChatWeb.Components.UI.Conversations do
  @moduledoc """
  Conversations sidebar component for the showcase design system.

  The sidebar is IRC-native: it presents joined channels, recent private
  messages, the account auto-join list, and popular channel suggestions without
  modeling a second workspace/navigation system. It remains hook-compatible with
  ConversationsHook through `phx-hook="ConversationsHook"` plus
  `data-channel` / `data-nick` attributes on actionable rows.

  ## Usage

      <.conversations
        channels={@channels}
        active_channel="#lobby"
        pm_conversations={@pms}
        channel_user_counts={%{"#lobby" => 12}}
        on_channel_click="switch_channel"
        on_close="toggle_conversations"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.EmptyState
  import RetroHexChatWeb.Components.UI.GroupCall.ChannelBadge
  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.P2P.SessionBadge

  alias RetroHexChatWeb.Icons

  @doc """
  Renders the conversations sidebar chrome. `visible` means expanded; when
  false, the mounted sidebar is replaced by the 36px rail.
  """
  attr :visible, :boolean, default: true
  attr :on_backdrop, :string, required: true
  attr :on_toggle, :string, required: true
  slot :rail, required: true
  slot :inner_block, required: true

  @spec conversations_sidebar(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations_sidebar(assigns) do
    assigns = assign(assigns, :state, if(assigns.visible, do: "expanded", else: "collapsed"))

    ~H"""
    <div
      class={[
        "chat-sidebar-overlay chat-sidebar-shell chat-sidebar-shell--left fixed inset-y-0 left-0 right-0 z-40",
        "flex shrink-0 md:relative md:inset-auto md:z-auto md:h-full",
        @visible && "chat-sidebar-shell--expanded",
        !@visible && "chat-sidebar-shell--collapsed"
      ]}
      data-state={@state}
      data-side="left"
      data-testid="conversations-sidebar-shell"
    >
      <div
        :if={@visible}
        class="chat-sidebar-backdrop absolute inset-0 bg-black/30 md:hidden"
        phx-click={@on_backdrop}
      />
      <div class="chat-sidebar-frame relative z-10 flex h-full min-h-0 bg-surface shadow-retro-window md:shadow-none">
        <%= if !@visible do %>
          {render_slot(@rail)}
        <% end %>
        <div class="chat-sidebar-panel min-w-0 flex-1">
          {render_slot(@inner_block)}
        </div>
      </div>
    </div>
    """
  end

  @doc "Renders the compact conversations rail used by the collapsed state."
  attr :expanded, :boolean, default: true
  attr :active_channel, :string, default: nil
  attr :active_pm, :string, default: nil
  attr :channel_count, :integer, default: 0
  attr :pm_count, :integer, default: 0
  attr :autojoin_count, :integer, default: 0
  attr :popular_count, :integer, default: 0
  attr :unread_count, :integer, default: 0
  attr :on_toggle, :any, required: true

  @spec conversations_rail(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations_rail(assigns) do
    assigns =
      assigns
      |> assign(
        :active_label,
        assigns.active_pm || assigns.active_channel || dgettext("chat", "Status")
      )
      |> assign(:active_icon, if(assigns.active_pm, do: :pm, else: :channel))

    ~H"""
    <nav
      class="chat-sidebar-rail chat-sidebar-rail--left"
      aria-label={dgettext("chat", "Conversations rail")}
      data-testid="conversations-rail"
    >
      <button
        type="button"
        class="chat-sidebar-rail__button chat-sidebar-rail__button--toggle"
        phx-click={@on_toggle}
        title={
          if @expanded,
            do: dgettext("chat", "Collapse conversations"),
            else: dgettext("chat", "Expand conversations")
        }
        aria-label={
          if @expanded,
            do: dgettext("chat", "Collapse conversations"),
            else: dgettext("chat", "Expand conversations")
        }
        aria-expanded={to_string(@expanded)}
        data-testid="conversations-rail-toggle"
      >
        <Icons.icon_chevron_left :if={@expanded} class="h-4 w-4" />
        <Icons.icon_chevron_right :if={!@expanded} class="h-4 w-4" />
      </button>

      <.conversations_rail_item
        icon={@active_icon}
        label={@active_label}
        active
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.conversations_rail_item
        icon={:channels}
        label={dgettext("chat", "Open channels")}
        count={@channel_count}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.conversations_rail_item
        icon={:pms}
        label={dgettext("chat", "Private messages")}
        count={@pm_count}
        badge={@unread_count}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.conversations_rail_item
        icon={:autojoin}
        label={dgettext("chat", "Auto-join")}
        count={@autojoin_count}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
      <.conversations_rail_item
        icon={:popular}
        label={dgettext("chat", "Popular channels")}
        count={@popular_count}
        expanded={@expanded}
        on_toggle={@on_toggle}
      />
    </nav>
    """
  end

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :count, :integer, default: nil
  attr :badge, :integer, default: 0
  attr :active, :boolean, default: false
  attr :expanded, :boolean, default: true
  attr :on_toggle, :any, required: true

  defp conversations_rail_item(assigns) do
    assigns =
      assign(assigns, :title, rail_item_title(assigns.label, assigns.count))

    ~H"""
    <button
      type="button"
      class={[
        "chat-sidebar-rail__button",
        @active && "chat-sidebar-rail__button--active"
      ]}
      phx-click={if @expanded, do: nil, else: @on_toggle}
      title={@title}
      aria-label={@title}
    >
      <.conversations_rail_icon icon={@icon} />
      <span :if={is_integer(@count)} class="chat-sidebar-rail__count">{@count}</span>
      <span :if={@badge > 0} class="chat-sidebar-rail__badge">
        {format_unread_count(@badge)}
      </span>
    </button>
    """
  end

  attr :icon, :atom, required: true

  defp conversations_rail_icon(%{icon: :channel} = assigns) do
    ~H"""
    <Icons.icon_tab_channel class="h-4 w-4" />
    """
  end

  defp conversations_rail_icon(%{icon: :pm} = assigns) do
    ~H"""
    <Icons.icon_tab_pm class="h-4 w-4" />
    """
  end

  defp conversations_rail_icon(%{icon: :channels} = assigns) do
    ~H"""
    <Icons.icon_btn_channel_list class="h-4 w-4" />
    """
  end

  defp conversations_rail_icon(%{icon: :pms} = assigns) do
    ~H"""
    <Icons.icon_tab_pm class="h-4 w-4" />
    """
  end

  defp conversations_rail_icon(%{icon: :autojoin} = assigns) do
    ~H"""
    <Icons.icon_dialog_autojoin class="h-4 w-4" />
    """
  end

  defp conversations_rail_icon(%{icon: :popular} = assigns) do
    ~H"""
    <Icons.icon_star class="h-4 w-4" />
    """
  end

  @doc "Renders the conversations sidebar with IRC-native semantic sections."
  attr :id, :string, default: "conversations"
  attr :channels, :list, default: []
  attr :active_channel, :string, default: nil
  attr :unread_channels, :list, default: []
  attr :unread_counts, :map, default: %{}, doc: "Map of channel/pm name to unread count"
  attr :highlight_channels, :list, default: []
  attr :flash_channels, :list, default: [], doc: "Channels with recent activity flash"
  attr :muted_channels, :list, default: []
  attr :disconnected_channels, :list, default: [], doc: "Channels marked disconnected"
  attr :group_call_channels, :list, default: [], doc: "Channels with an active conference"
  attr :group_call_summaries, :map, default: %{}, doc: "Conference summaries keyed by channel"
  attr :p2p_peer, :string, default: nil, doc: "Peer nick for the active P2P session"
  attr :p2p_session, :map, default: nil, doc: "Active P2P session read model"

  attr :p2p_pm_sessions, :map,
    default: %{},
    doc: "Pending P2P session read models keyed by downcased PM nick"

  attr :open_pm_tabs, :list, default: [], doc: "PM tabs currently open in the MDI tab bar"
  attr :pm_conversations, :list, default: []

  attr :pm_conversations_truncated, :boolean,
    default: false,
    doc: "The account has more conversations than the sidebar restored"

  attr :autojoin_entries, :list, default: [], doc: "Auto-join entries from the session"
  attr :active_pm, :string, default: nil
  attr :unread_pms, :list, default: []

  attr :nick_color_fn, :any, default: nil, doc: "Function(nick) -> CSS class for nick coloring"
  attr :channel_user_counts, :map, default: %{}, doc: "Map of channel name to user count"
  attr :popular_channels, :list, default: [], doc: "List of maps with :name and :user_count"
  attr :collapsed_sections, :list, default: [], doc: "List of collapsed section keys"
  attr :on_channel_click, :any, default: nil, doc: "Channel click callback"
  attr :on_channel_dblclick, :any, default: nil, doc: "Channel double-click callback"
  attr :on_pm_click, :any, default: nil, doc: "PM click callback"
  attr :on_toggle_section, :any, default: nil, doc: "Section toggle callback"
  attr :on_close, :any, default: nil, doc: "Close/hide sidebar callback"
  attr :on_browse_channels, :any, default: nil, doc: "Browse channels callback"
  attr :on_join_popular, :any, default: nil, doc: "Join popular channel callback"
  attr :on_autojoin_open, :any, default: nil, doc: "Open auto-join window callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations(assigns) do
    assigns =
      assign(assigns,
        activity_channels: activity_channels(assigns),
        activity_pms: activity_pms(assigns),
        has_conversations_content: has_conversations_content?(assigns),
        channel_count: length(assigns.channels),
        pm_count: length(assigns.pm_conversations),
        autojoin_count: length(assigns.autojoin_entries),
        popular_section_visible: popular_section_visible?(assigns),
        popular_section_count: popular_section_count(assigns.popular_channels)
      )

    ~H"""
    <div
      class={classes(["flex h-full min-h-0 flex-col", @class])}
      id={@id}
      phx-hook="ConversationsHook"
      data-testid="conversations"
      {@rest}
    >
      <div class="chat-conversations-titlebar">
        <.button
          :if={@on_close}
          type="button"
          variant="outline"
          size="icon"
          class="chat-sidebar-collapse-button"
          phx-click={@on_close}
          title={dgettext("chat", "Collapse conversations")}
          aria-label={dgettext("chat", "Collapse conversations")}
          data-testid="conversations-collapse-toggle"
        >
          <:icon><Icons.icon_chevron_left class="h-4 w-4" /></:icon>
          <span class="sr-only">{dgettext("chat", "Collapse conversations")}</span>
        </.button>
        <Icons.icon_tab_conversations class="w-4 h-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate text-xs font-bold">
          {dgettext("chat", "Conversations")}
        </span>
      </div>

      <div class="chat-conversations-status-strip">
        <.conversation_stat
          label={dgettext("chat", "OPEN CHANNELS")}
          short_label={dgettext("chat", "Channels")}
          count={@channel_count}
          icon={:channels}
          testid="conversations-stat-channels"
        />
        <.conversation_stat
          label={dgettext("chat", "RECENT PRIVATE MESSAGES")}
          short_label={dgettext("chat", "PM")}
          count={@pm_count}
          icon={:pms}
          testid="conversations-stat-pms"
        />
        <.conversation_stat
          label={dgettext("chat", "AUTO-JOIN")}
          short_label={dgettext("chat", "Auto")}
          count={@autojoin_count}
          icon={:autojoin}
          testid="conversations-stat-autojoin"
        />
      </div>

      <div class="chat-conversations-body flex-1 min-h-0 overflow-y-auto retro-scrollbar shadow-retro-field">
        <%= if !@has_conversations_content do %>
          <.empty_state>
            <:icon><Icons.icon_channels class="w-6 h-6" /></:icon>
            <:title>{dgettext("chat", "No channels")}</:title>
            <:description>{dgettext("chat", "/join #channel to get started")}</:description>
            <:action>
              <.button
                :if={@on_browse_channels}
                variant="outline"
                size="sm"
                phx-click={@on_browse_channels}
                data-testid="conversations-browse-channels"
              >
                <:icon><Icons.icon_btn_channel_list class="w-4 h-4" /></:icon>
                {dgettext("chat", "Browse channels")}
              </.button>
            </:action>
          </.empty_state>
        <% else %>
          <.conversation_section
            :if={@activity_channels != [] or @activity_pms != []}
            label={dgettext("chat", "ACTIVITY")}
            section="alerts"
            count={length(@activity_channels) + length(@activity_pms)}
            open={section_open?(@collapsed_sections, "alerts")}
            on_toggle={@on_toggle_section}
            testid="conversations-section-alerts"
          >
            <.channel_item
              :for={ch <- @activity_channels}
              name={ch}
              active={ch == @active_channel}
              unread={member?(@unread_channels, ch)}
              unread_count={unread_count(@unread_counts, ch)}
              highlight={member?(@highlight_channels, ch) or member?(@flash_channels, ch)}
              flash={member?(@flash_channels, ch)}
              muted={member?(@muted_channels, ch)}
              disconnected={member?(@disconnected_channels, ch)}
              group_call_active={member?(@group_call_channels, ch)}
              group_call_summary={Map.get(@group_call_summaries || %{}, ch)}
              user_count={Map.get(@channel_user_counts || %{}, ch)}
              on_click={@on_channel_click}
              on_dblclick={@on_channel_dblclick}
              testid={"activity-channel-#{ch}"}
              unread_badge_testid={"activity-channel-unread-badge-#{ch}"}
              unread_dot_testid={"activity-channel-unread-dot-#{ch}"}
              activity
            />

            <.pm_item
              :for={pm <- @activity_pms}
              nick={pm}
              active={pm == @active_pm}
              open_tab={member?(@open_pm_tabs, pm)}
              unread={member?(@unread_pms, pm)}
              highlight={member?(@highlight_channels, "pm:#{pm}")}
              unread_count={unread_count(@unread_counts, "pm:#{pm}")}
              flash={member?(@flash_channels, "pm:#{pm}")}
              muted={member?(@muted_channels, "pm:#{pm}")}
              nick_color={nick_color(assigns, pm)}
              p2p_session={p2p_session_for_pm(assigns, pm)}
              on_click={@on_pm_click}
              testid={"activity-pm-#{pm}"}
              unread_badge_testid={"activity-pm-unread-badge-#{pm}"}
              unread_dot_testid={"activity-pm-unread-dot-#{pm}"}
              activity
            />
          </.conversation_section>

          <.conversation_section
            :if={@channels != []}
            label={dgettext("chat", "OPEN CHANNELS")}
            section="channels"
            count={length(@channels)}
            open={section_open?(@collapsed_sections, "channels")}
            on_toggle={@on_toggle_section}
            testid="conversations-section-channels"
          >
            <.channel_item
              :for={ch <- @channels}
              name={ch}
              active={ch == @active_channel}
              unread={member?(@unread_channels, ch)}
              unread_count={unread_count(@unread_counts, ch)}
              highlight={member?(@highlight_channels, ch) or member?(@flash_channels, ch)}
              flash={member?(@flash_channels, ch)}
              muted={member?(@muted_channels, ch)}
              disconnected={member?(@disconnected_channels, ch)}
              group_call_active={member?(@group_call_channels, ch)}
              group_call_summary={Map.get(@group_call_summaries || %{}, ch)}
              user_count={Map.get(@channel_user_counts || %{}, ch)}
              on_click={@on_channel_click}
              on_dblclick={@on_channel_dblclick}
            />
          </.conversation_section>

          <.conversation_section
            :if={@pm_conversations != []}
            label={dgettext("chat", "RECENT PRIVATE MESSAGES")}
            section="pms"
            count={length(@pm_conversations)}
            open={section_open?(@collapsed_sections, "pms")}
            on_toggle={@on_toggle_section}
            testid="conversations-section-pms"
          >
            <.pm_item
              :for={pm <- @pm_conversations}
              nick={pm}
              active={pm == @active_pm}
              open_tab={member?(@open_pm_tabs, pm)}
              unread={member?(@unread_pms, pm)}
              highlight={member?(@highlight_channels, "pm:#{pm}")}
              unread_count={unread_count(@unread_counts, "pm:#{pm}")}
              flash={member?(@flash_channels, "pm:#{pm}")}
              muted={member?(@muted_channels, "pm:#{pm}")}
              nick_color={nick_color(assigns, pm)}
              p2p_session={p2p_session_for_pm(assigns, pm)}
              on_click={@on_pm_click}
            />

            <li :if={@pm_conversations_truncated}>
              <.list_end_marker
                variant={:more}
                testid="conversations-pms-truncated"
              />
            </li>
          </.conversation_section>

          <.conversation_section
            :if={@autojoin_entries != []}
            label={dgettext("chat", "AUTO-JOIN")}
            section="autojoin"
            count={length(@autojoin_entries)}
            open={section_open?(@collapsed_sections, "autojoin")}
            on_toggle={@on_toggle_section}
            testid="conversations-section-autojoin"
          >
            <.autojoin_item
              :for={entry <- @autojoin_entries}
              entry={entry}
              joined={member?(@channels, entry_channel_name(entry))}
              on_open={@on_autojoin_open}
            />
          </.conversation_section>

          <.conversation_section
            :if={@popular_section_visible}
            label={dgettext("chat", "POPULAR CHANNELS")}
            section="popular"
            count={@popular_section_count}
            open={section_open?(@collapsed_sections, "popular")}
            on_toggle={@on_toggle_section}
            testid="conversations-section-popular"
          >
            <.popular_item
              :for={ch <- @popular_channels}
              channel={ch}
              on_join={@on_join_popular}
            />

            <li :if={@on_browse_channels} class="chat-conversations-browse-row">
              <.button
                type="button"
                variant="ghost"
                size="sm"
                class="chat-conversations-browse-button"
                phx-click={@on_browse_channels}
                data-testid="conversations-browse-all"
              >
                <:icon><Icons.icon_dialog_channel_list class="w-3.5 h-3.5" /></:icon>
                {dgettext("chat", "Browse All Channels...")}
              </.button>
            </li>
          </.conversation_section>
        <% end %>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :section, :string, required: true
  attr :count, :integer, default: nil
  attr :open, :boolean, default: true
  attr :on_toggle, :any, default: nil
  attr :testid, :string, required: true
  slot :inner_block, required: true

  defp conversation_section(assigns) do
    ~H"""
    <section
      class={[
        "chat-conversations-section",
        @section == "alerts" && "chat-conversations-section--alerts",
        @section == "autojoin" && "chat-conversations-section--autojoin",
        @section == "popular" && "chat-conversations-section--popular"
      ]}
      data-testid={@testid}
    >
      <button
        type="button"
        class="chat-conversations-section__trigger"
        phx-click={@on_toggle}
        phx-value-section={@section}
        aria-expanded={to_string(@open)}
      >
        <span class="chat-conversations-section__toggle">
          {if @open, do: "-", else: "+"}
        </span>
        <span class="chat-conversations-section__label">{@label}</span>
        <span
          :if={!is_nil(@count)}
          class="chat-conversations-section__count"
        >
          {@count}
        </span>
      </button>

      <ul :if={@open} class="chat-conversations-section__list" role="list">
        {render_slot(@inner_block)}
      </ul>
    </section>
    """
  end

  attr :name, :string, required: true
  attr :active, :boolean, default: false
  attr :unread, :boolean, default: false
  attr :unread_count, :integer, default: 0
  attr :highlight, :boolean, default: false
  attr :flash, :boolean, default: false
  attr :muted, :boolean, default: false
  attr :disconnected, :boolean, default: false
  attr :group_call_active, :boolean, default: false
  attr :group_call_summary, :map, default: nil
  attr :user_count, :integer, default: nil
  attr :on_click, :any, default: nil
  attr :on_dblclick, :any, default: nil
  attr :testid, :string, default: nil
  attr :unread_badge_testid, :string, default: nil
  attr :unread_dot_testid, :string, default: nil
  attr :activity, :boolean, default: false

  defp channel_item(assigns) do
    assigns =
      assign(assigns,
        testid: assigns.testid || "channel-#{assigns.name}",
        unread_badge_testid:
          assigns.unread_badge_testid || "channel-unread-badge-#{assigns.name}",
        unread_dot_testid: assigns.unread_dot_testid || "channel-unread-dot-#{assigns.name}"
      )

    ~H"""
    <li
      class={[
        row_classes(@active),
        @activity && "chat-conversations-row--activity",
        @unread && !@active && "font-bold",
        @highlight && !@active && "text-error",
        @flash && "animate-pulse",
        @muted && "opacity-50"
      ]}
      phx-click={@on_click}
      phx-value-channel={@name}
      phx-dblclick={@on_dblclick}
      data-channel={@name}
      data-muted={to_string(@muted)}
      data-unread={to_string(@unread)}
      data-group-call-active={to_string(@group_call_active)}
      data-testid={@testid}
      tabindex="0"
      aria-current={if @active, do: "page"}
    >
      <span class={status_bar_classes(@active, @highlight, @unread)} aria-hidden="true"></span>
      <span class="chat-conversations-row__icon">
        <span :if={@disconnected} title={dgettext("chat", "Disconnected")}>
          <Icons.icon_warning class="w-3 h-3 text-warning-alt" />
        </span>
        <Icons.icon_tab_channel :if={!@disconnected} class="w-3 h-3" />
      </span>
      <span class="chat-conversations-row__label">{@name}</span>
      <span :if={@muted} class="shrink-0" title={dgettext("chat", "Muted")}>
        <Icons.icon_mute class="w-3 h-3" />
      </span>
      <span
        :if={@group_call_active}
        class="shrink-0"
      >
        <.group_call_channel_glyph
          channel={@name}
          summary={@group_call_summary}
          testid={"channel-group-call-glyph-#{@name}"}
        />
      </span>
      <span
        :if={@user_count}
        class="chat-conversations-row__count"
      >
        ({@user_count})
      </span>
      <span
        :if={@unread && !@active && @unread_count > 0}
        class={unread_badge_classes(@highlight)}
        data-testid={@unread_badge_testid}
      >
        {format_unread_count(@unread_count)}
      </span>
      <span
        :if={@unread && !@active && @unread_count == 0}
        class="w-2 h-2 bg-link shrink-0"
        data-testid={@unread_dot_testid}
      />
    </li>
    """
  end

  attr :nick, :string, required: true
  attr :active, :boolean, default: false
  attr :open_tab, :boolean, default: false
  attr :unread, :boolean, default: false
  attr :unread_count, :integer, default: 0
  attr :highlight, :boolean, default: false
  attr :flash, :boolean, default: false
  attr :muted, :boolean, default: false
  attr :nick_color, :string, default: nil
  attr :p2p_session, :map, default: nil
  attr :on_click, :any, default: nil
  attr :testid, :string, default: nil
  attr :unread_badge_testid, :string, default: nil
  attr :unread_dot_testid, :string, default: nil
  attr :activity, :boolean, default: false

  defp pm_item(assigns) do
    assigns =
      assign(assigns,
        testid: assigns.testid || "pm-#{assigns.nick}",
        unread_badge_testid: assigns.unread_badge_testid || "pm-unread-badge-#{assigns.nick}",
        unread_dot_testid: assigns.unread_dot_testid || "pm-unread-dot-#{assigns.nick}"
      )

    ~H"""
    <li
      class={[
        row_classes(@active),
        @activity && "chat-conversations-row--activity",
        @unread && !@active && "font-bold italic",
        @highlight && !@active && "text-error",
        @flash && "animate-pulse",
        @muted && "opacity-50"
      ]}
      phx-click={@on_click}
      phx-value-nickname={@nick}
      data-nick={@nick}
      data-muted={to_string(@muted)}
      data-unread={to_string(@unread)}
      data-testid={@testid}
      tabindex="0"
      aria-current={if @active, do: "page"}
    >
      <span class={status_bar_classes(@active, @highlight, @unread)} aria-hidden="true"></span>
      <span class="chat-conversations-row__icon">
        <Icons.icon_tab_pm class="w-3 h-3" />
      </span>
      <span class={["chat-conversations-row__label", !@active && @nick_color]}>{@nick}</span>
      <span
        :if={@open_tab}
        class="chat-conversations-chip chat-conversations-chip--tab"
        data-testid={"pm-open-state-#{@nick}"}
      >
        {dgettext("chat", "tab")}
      </span>
      <span :if={@muted} class="shrink-0" title={dgettext("chat", "Muted")}>
        <Icons.icon_mute class="w-3 h-3" />
      </span>
      <span :if={@p2p_session} class="shrink-0">
        <.p2p_peer_glyph
          peer={@nick}
          session={@p2p_session}
          testid={"pm-p2p-glyph-#{@nick}"}
        />
      </span>
      <span
        :if={@unread && !@active && @unread_count > 0}
        class="chat-conversations-unread-badge"
        data-testid={@unread_badge_testid}
      >
        {format_unread_count(@unread_count)}
      </span>
      <span
        :if={@unread && !@active && @unread_count == 0}
        class="w-2 h-2 bg-link shrink-0"
        data-testid={@unread_dot_testid}
      />
    </li>
    """
  end

  attr :entry, :map, required: true
  attr :joined, :boolean, default: false
  attr :on_open, :any, default: nil

  defp autojoin_item(assigns) do
    assigns =
      assign(assigns,
        channel_name: entry_channel_name(assigns.entry),
        has_key: present?(value(assigns.entry, :channel_key))
      )

    ~H"""
    <li
      class={row_classes(false, false)}
      data-autojoin-channel={@channel_name}
      data-testid={"autojoin-#{@channel_name}"}
    >
      <span class={autojoin_signal_classes(@joined, @has_key)} aria-hidden="true"></span>
      <span class="chat-conversations-row__icon">
        <Icons.icon_dialog_autojoin class="w-3 h-3" />
      </span>
      <span class="chat-conversations-row__label">{@channel_name}</span>
      <span
        :if={@joined}
        class="chat-conversations-chip chat-conversations-chip--open"
      >
        {dgettext("chat", "open")}
      </span>
      <span
        :if={@has_key}
        class="chat-conversations-chip chat-conversations-chip--key"
      >
        +key
      </span>
      <.button
        :if={@on_open}
        type="button"
        variant="ghost"
        size="icon"
        class="ml-1 shrink-0 w-4 h-4 min-h-0"
        phx-click={@on_open}
        title={dgettext("chat", "Edit auto-join channels")}
        data-testid={"autojoin-open-#{@channel_name}"}
      >
        <:icon><Icons.icon_btn_autojoin class="w-3 h-3" /></:icon>
      </.button>
    </li>
    """
  end

  attr :channel, :map, required: true, doc: "Map with :name and :user_count"
  attr :on_join, :any, default: nil

  defp popular_item(assigns) do
    assigns =
      assign(assigns,
        channel_name: value(assigns.channel, :name),
        user_count: value(assigns.channel, :user_count)
      )

    ~H"""
    <li class={row_classes(false, false)} data-testid={"popular-#{@channel_name}"}>
      <span class={status_bar_classes(false, false, false)} aria-hidden="true"></span>
      <span class="chat-conversations-row__icon">
        <Icons.icon_tab_channel class="w-3 h-3" />
      </span>
      <span class="chat-conversations-row__label">{@channel_name}</span>
      <span class="chat-conversations-row__count">({@user_count})</span>
      <.button
        :if={@on_join}
        type="button"
        variant="ghost"
        size="icon"
        class="ml-1 shrink-0 w-4 h-4 min-h-0"
        phx-click={@on_join}
        phx-value-channel={@channel_name}
        title={dgettext("chat", "Join %{channel}", channel: @channel_name)}
        data-testid={"join-#{@channel_name}"}
      >
        <:icon><Icons.icon_btn_add class="w-3 h-3" /></:icon>
      </.button>
    </li>
    """
  end

  defp row_classes(active, interactive \\ true) do
    [
      "chat-conversations-row",
      if(interactive,
        do: "chat-conversations-row--interactive",
        else: "chat-conversations-row--static"
      ),
      active && "chat-conversations-row--active"
    ]
  end

  defp status_bar_classes(active, highlight, unread) do
    [
      "chat-conversations-row__signal",
      cond do
        active -> "chat-conversations-row__signal--active"
        highlight -> "chat-conversations-row__signal--highlight"
        unread -> "chat-conversations-row__signal--unread"
        true -> "chat-conversations-row__signal--idle"
      end
    ]
  end

  defp autojoin_signal_classes(joined, has_key) do
    [
      "chat-conversations-row__signal",
      cond do
        joined -> "chat-conversations-row__signal--autojoin-open"
        has_key -> "chat-conversations-row__signal--autojoin-key"
        true -> "chat-conversations-row__signal--autojoin-saved"
      end
    ]
  end

  defp unread_badge_classes(highlight) do
    [
      "chat-conversations-unread-badge",
      highlight && "chat-conversations-unread-badge--highlight"
    ]
  end

  attr :label, :string, required: true
  attr :short_label, :string, required: true
  attr :count, :integer, required: true
  attr :icon, :atom, required: true
  attr :testid, :string, required: true

  defp conversation_stat(assigns) do
    ~H"""
    <span class="chat-conversations-stat" title={@label} data-testid={@testid}>
      <.stat_icon icon={@icon} />
      <span class="chat-conversations-stat__value">{@count}</span>
      <span class="chat-conversations-stat__label">{@short_label}</span>
    </span>
    """
  end

  attr :icon, :atom, required: true

  defp stat_icon(%{icon: :channels} = assigns) do
    ~H"""
    <Icons.icon_tab_channel class="h-3 w-3" />
    """
  end

  defp stat_icon(%{icon: :pms} = assigns) do
    ~H"""
    <Icons.icon_tab_pm class="h-3 w-3" />
    """
  end

  defp stat_icon(%{icon: :autojoin} = assigns) do
    ~H"""
    <Icons.icon_dialog_autojoin class="h-3 w-3" />
    """
  end

  defp activity_channels(assigns) do
    Enum.filter(assigns.channels, fn channel ->
      unread_count(assigns.unread_counts, channel) > 0 or
        member?(assigns.unread_channels, channel) or
        member?(assigns.highlight_channels, channel) or
        member?(assigns.flash_channels, channel)
    end)
  end

  defp activity_pms(assigns) do
    Enum.filter(assigns.pm_conversations, fn nick ->
      key = "pm:#{nick}"

      unread_count(assigns.unread_counts, key) > 0 or
        member?(assigns.unread_pms, nick) or
        member?(assigns.highlight_channels, key) or
        member?(assigns.flash_channels, key)
    end)
  end

  defp has_conversations_content?(assigns) do
    assigns.channels != [] or assigns.pm_conversations != [] or assigns.autojoin_entries != [] or
      assigns.popular_channels != [] or present?(assigns.on_browse_channels)
  end

  defp popular_section_visible?(assigns) do
    assigns.popular_channels != [] or present?(assigns.on_browse_channels)
  end

  defp popular_section_count([]), do: nil
  defp popular_section_count(channels), do: length(channels)

  defp section_open?(collapsed_sections, section) do
    not member?(collapsed_sections, section)
  end

  defp member?(%MapSet{} = values, value), do: MapSet.member?(values, value)
  defp member?(values, value) when is_list(values), do: value in values
  defp member?(_values, _value), do: false

  defp unread_count(unread_counts, key) when is_map(unread_counts) do
    Map.get(unread_counts, key, 0)
  end

  defp unread_count(_unread_counts, _key), do: 0

  defp format_unread_count(count) when is_integer(count) and count > 99, do: "99+"
  defp format_unread_count(count), do: count

  defp rail_item_title(label, count) when is_integer(count), do: "#{label}: #{count}"
  defp rail_item_title(label, _count), do: label

  defp nick_color(assigns, nick) do
    if is_function(assigns.nick_color_fn, 1), do: assigns.nick_color_fn.(nick)
  end

  defp entry_channel_name(entry), do: value(entry, :channel_name)

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp p2p_peer_key(assigns) do
    peer = assigns.p2p_peer || value(assigns.p2p_session, :peer_nick)
    if is_binary(peer), do: String.downcase(peer)
  end

  defp p2p_session_for_pm(assigns, nick) when is_binary(nick) do
    key = String.downcase(nick)

    cond do
      p2p_peer_key(assigns) == key and is_map(assigns.p2p_session) ->
        assigns.p2p_session

      is_map(assigns.p2p_pm_sessions) ->
        Map.get(assigns.p2p_pm_sessions, key)

      true ->
        nil
    end
  end

  defp p2p_session_for_pm(_assigns, _nick), do: nil

  # Nil-safe because the session it reads is absent more often than present.
  defp value(nil, _key), do: nil
  defp value(map, key) when is_map(map) and is_atom(key), do: Map.get(map, key)
end

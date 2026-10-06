defmodule RetroHexChatWeb.Components.UI.Conversations do
  @moduledoc """
  Conversations sidebar component for the showcase design system.

  The sidebar is IRC-native: it presents joined channels ordered by recent
  activity, recent private messages, the account auto-join list, and popular
  channel suggestions without modeling a second workspace/navigation system. It
  remains hook-compatible with ConversationsHook through
  `phx-hook="ConversationsHook"` plus `data-channel` / `data-nick` attributes on
  actionable rows.

  ## One grammar, every row

  A row is a place. Clicking it goes there, joining first if that is what going
  there requires, and every row in every section answers a click that way —
  there are no inert rows a click passes through.

  Everything that is not "go" is reached from the row's own menu button, which
  opens the same menu right-click and long-press open. A gesture is an
  accelerator here and never the only way to something: right-click has no
  equivalent a finger can discover, and long-press announces itself to nobody.
  The button is what teaches both.

  The per-row shortcuts beside it — join a suggestion, edit the auto-join list —
  are desktop accelerators layered on top of that, never the only path either.
  At a phone's width they are not rendered at all, so a row has exactly two
  targets: itself, and its menu.

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

  import RetroHexChatWeb.Components.UI.MentionBadge
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ToolButton
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
      <.tool_button
        label={
          if @expanded,
            do: dgettext("chat", "Collapse conversations"),
            else: dgettext("chat", "Expand conversations")
        }
        variant="flat"
        size="xs"
        active={@expanded}
        class="chat-sidebar-rail__button"
        phx-click={@on_toggle}
        aria-expanded={to_string(@expanded)}
        data-testid="conversations-rail-toggle"
      >
        <Icons.icon_chevron_left :if={@expanded} class="h-4 w-4" />
        <Icons.icon_chevron_right :if={!@expanded} class="h-4 w-4" />
      </.tool_button>

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
    <.tool_button
      label={@title}
      variant="flat"
      size="xs"
      active={@active}
      class="chat-sidebar-rail__button"
      phx-click={if @expanded, do: nil, else: @on_toggle}
    >
      <.conversations_rail_icon icon={@icon} />
      <span :if={is_integer(@count)} class="chat-sidebar-rail__count">{@count}</span>
      <span :if={@badge > 0} class="chat-sidebar-rail__badge">
        {format_unread_count(@badge)}
      </span>
    </.tool_button>
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

  attr :mention_counts, :map,
    default: %{},
    doc: "Map of channel/pm name to how many of those are about the reader"

  attr :channel_activity_order, :map,
    default: %{},
    doc: "Monotonic activity order keyed by channel name"

  attr :highlight_channels, :list, default: []
  attr :flash_channels, :list, default: [], doc: "Channels with recent activity flash"
  attr :muted_channels, :list, default: []
  attr :disconnected_channels, :list, default: [], doc: "Channels marked disconnected"
  attr :group_call_channels, :list, default: [], doc: "Channels with an active conference"
  attr :group_call_summaries, :map, default: %{}, doc: "Conference summaries keyed by channel"

  attr :p2p_pm_sessions, :map,
    default: %{},
    doc: "P2P session read models keyed by downcased PM nick"

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

  attr :mobile, :boolean,
    default: false,
    doc: "Phone width: the row keeps two targets and drops the desktop accelerators"

  attr :on_channel_click, :any, default: nil, doc: "Channel click callback"
  attr :on_pm_click, :any, default: nil, doc: "PM click callback"
  attr :on_toggle_section, :any, default: nil, doc: "Section toggle callback"
  attr :on_close, :any, default: nil, doc: "Close/hide sidebar callback"
  attr :on_browse_channels, :any, default: nil, doc: "Browse channels callback"
  attr :on_join_popular, :any, default: nil, doc: "Join popular channel callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec conversations(map()) :: Phoenix.LiveView.Rendered.t()
  def conversations(assigns) do
    channel_rows = channel_rows(assigns)

    assigns =
      assign(assigns,
        channel_rows: channel_rows,
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
        <.tool_button
          :if={@on_close}
          label={dgettext("chat", "Collapse conversations")}
          variant="flat"
          size="sm"
          phx-click={@on_close}
          data-testid="conversations-collapse-toggle"
        >
          <Icons.icon_chevron_left class="h-4 w-4" />
        </.tool_button>
        <Icons.icon_tab_conversations class="w-4 h-4 shrink-0" />
        <span class="min-w-0 flex-1 truncate text-xs font-bold">
          {dgettext("chat", "Conversations")}
        </span>
      </div>

      <div class="chat-conversations-status-strip">
        <.conversation_stat
          label={dgettext("chat", "Open channels")}
          short_label={dgettext("chat", "Channels")}
          count={@channel_count}
          icon={:channels}
          testid="conversations-stat-channels"
        />
        <.conversation_stat
          label={dgettext("chat", "Recent private messages")}
          short_label={dgettext("chat", "PM")}
          count={@pm_count}
          icon={:pms}
          testid="conversations-stat-pms"
        />
        <.conversation_stat
          label={dgettext("chat", "Joined on connect")}
          short_label={dgettext("chat", "Auto")}
          count={@autojoin_count}
          icon={:autojoin}
          testid="conversations-stat-autojoin"
        />
      </div>

      <div class="chat-conversations-body flex-1 min-h-0 overflow-y-auto shadow-retro-field">
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
          <%!-- Open channels and the ones the account joins on connect are the
                same rooms, so they are one list. Split in two they appeared
                twice over — the open half answering a click, the saved half
                answering nothing — and a name in both places meant two rows
                for one door. Which half a row is in is now the grey of its
                name, and the pin on it says the list still holds it. --%>
          <.conversation_section
            :if={@channel_rows != []}
            label={dgettext("chat", "Channels")}
            section="channels"
            count={length(@channel_rows)}
            open={section_open?(@collapsed_sections, "channels")}
            on_toggle={@on_toggle_section}
            testid="conversations-section-channels"
          >
            <.channel_item
              :for={row <- @channel_rows}
              name={row.name}
              joined={row.joined}
              pinned={row.pinned}
              has_key={row.has_key}
              active={row.name == @active_channel}
              unread={member?(@unread_channels, row.name)}
              unread_count={unread_count(@unread_counts, row.name)}
              mention_count={unread_count(@mention_counts, row.name)}
              highlight={member?(@highlight_channels, row.name) or member?(@flash_channels, row.name)}
              flash={member?(@flash_channels, row.name)}
              muted={member?(@muted_channels, row.name)}
              disconnected={member?(@disconnected_channels, row.name)}
              group_call_active={member?(@group_call_channels, row.name)}
              group_call_summary={Map.get(@group_call_summaries || %{}, row.name)}
              user_count={Map.get(@channel_user_counts || %{}, row.name)}
              on_click={@on_channel_click}
            />
          </.conversation_section>

          <.conversation_section
            :if={@pm_conversations != []}
            label={dgettext("chat", "Recent private messages")}
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
              mention_count={unread_count(@mention_counts, "pm:#{pm}")}
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
            :if={@popular_section_visible}
            label={dgettext("chat", "Popular channels")}
            discovery
            section="popular"
            count={@popular_section_count}
            open={section_open?(@collapsed_sections, "popular")}
            on_toggle={@on_toggle_section}
            testid="conversations-section-popular"
          >
            <.popular_item
              :for={ch <- @popular_channels}
              channel={ch}
              mobile={@mobile}
              on_join={@on_join_popular}
            />
          </.conversation_section>
        <% end %>
      </div>

      <%!-- The way to every room there is. It used to be an <li> inside the
            suggestions list — a row that was not a row, in a section that
            collapses, so the one door that is always right went away with the
            suggestions. It is the sidebar's footer now: outside the scroll,
            outside the sections, always there. --%>
      <div :if={@on_browse_channels} class="chat-conversations-footer">
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
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :section, :string, required: true
  attr :count, :integer, default: nil
  attr :open, :boolean, default: true
  attr :on_toggle, :any, default: nil

  attr :discovery, :boolean,
    default: false,
    doc: "Rooms you are not in: set apart from the lists of rooms you are"

  attr :testid, :string, required: true
  slot :inner_block, required: true

  defp conversation_section(assigns) do
    ~H"""
    <section
      class={[
        "chat-conversations-section",
        @discovery && "chat-conversations-section--discovery"
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
  attr :joined, :boolean, default: true, doc: "false means saved but not open — a click joins it"
  attr :pinned, :boolean, default: false, doc: "on the account's auto-join list"
  attr :has_key, :boolean, default: false, doc: "the saved auto-join entry carries a key"
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
  attr :testid, :string, default: nil
  attr :unread_badge_testid, :string, default: nil
  attr :unread_dot_testid, :string, default: nil
  attr :mention_count, :integer, default: 0

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
        !@joined && "chat-conversations-row--saved",
        @unread && !@active && "font-bold",
        @highlight && !@active && "chat-conversations-row--highlight",
        @flash && "animate-pulse",
        @muted && "chat-conversations-row--muted"
      ]}
      phx-click={@on_click}
      phx-value-channel={@name}
      data-channel={@name}
      data-joined={to_string(@joined)}
      data-pinned={to_string(@pinned)}
      data-muted={to_string(@muted)}
      data-unread={to_string(@unread)}
      data-group-call-active={to_string(@group_call_active)}
      data-testid={@testid}
      title={channel_row_title(@name, @user_count, @joined)}
      tabindex="0"
      aria-current={if @active, do: "page"}
    >
      <span class="chat-conversations-row__icon">
        <span :if={@disconnected} title={dgettext("chat", "Disconnected")}>
          <Icons.icon_warning class="w-3 h-3 text-warning-alt" />
        </span>
        <Icons.icon_tab_channel :if={!@disconnected} class="w-3 h-3" />
      </span>
      <span class="chat-conversations-row__label">{@name}</span>
      <%!-- The auto-join list, said on the channel itself. It is an attribute of
            a place, and it used to be a section of its own listing the same
            rooms a second time — one of them inert, so the same name answered a
            click two ways. Toggling it is a menu item, at a size a finger can
            hit; this is the indicator, and on a desktop also the shortcut. --%>
      <span
        :if={@pinned}
        class="chat-conversations-row__pin"
        title={autojoin_title(@has_key)}
        data-testid={"channel-autojoin-pin-#{@name}"}
        aria-hidden="true"
      >
        <Icons.icon_dialog_autojoin class="w-3 h-3" />
      </span>
      <.row_status
        name={@name}
        kind="channel"
        muted={@muted}
        group_call_active={@group_call_active}
        group_call_summary={@group_call_summary}
      />
      <.row_count
        mention_count={@mention_count}
        unread_count={@unread_count}
        unread={@unread}
        active={@active}
        highlight={@highlight}
        mention_testid={"channel-mention-badge-#{@name}"}
        unread_badge_testid={@unread_badge_testid}
        unread_dot_testid={@unread_dot_testid}
      />
      <.row_menu_button name={@name} />
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
  attr :mention_count, :integer, default: 0

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
        !@open_tab && "chat-conversations-row--saved",
        @unread && !@active && "font-bold italic",
        @highlight && !@active && "chat-conversations-row--highlight",
        @flash && "animate-pulse",
        @muted && "chat-conversations-row--muted"
      ]}
      phx-click={@on_click}
      phx-value-nickname={@nick}
      data-nick={@nick}
      data-joined={to_string(@open_tab)}
      data-muted={to_string(@muted)}
      data-unread={to_string(@unread)}
      data-testid={@testid}
      title={pm_row_title(@nick, @open_tab)}
      tabindex="0"
      aria-current={if @active, do: "page"}
    >
      <%!-- A conversation with no tab mounted reads the way a channel you have
            not opened reads: the same greyed name, not a word of its own. The
            chip that used to say "tab" here named a thing the sidebar knows and
            the reader does not, and channels carry tabs too without ever having
            said so. --%>
      <span class="chat-conversations-row__icon">
        <Icons.icon_tab_pm class="w-3 h-3" />
      </span>
      <span class={["chat-conversations-row__label", !@active && @nick_color]}>{@nick}</span>
      <.row_status
        name={@nick}
        kind="pm"
        muted={@muted}
        p2p_session={@p2p_session}
      />
      <.row_count
        mention_count={@mention_count}
        unread_count={@unread_count}
        unread={@unread}
        active={@active}
        highlight={@highlight}
        mention_testid={"pm-mention-badge-#{@nick}"}
        unread_badge_testid={@unread_badge_testid}
        unread_dot_testid={@unread_dot_testid}
      />
      <.row_menu_button name={@nick} />
    </li>
    """
  end

  attr :channel, :map, required: true, doc: "Map with :name and :user_count"
  attr :mobile, :boolean, default: false
  attr :on_join, :any, default: nil

  defp popular_item(assigns) do
    assigns =
      assign(assigns,
        channel_name: value(assigns.channel, :name),
        user_count: value(assigns.channel, :user_count)
      )

    ~H"""
    <%!-- A suggestion is a place like any other, so the row goes there. It used
          to be inert with a 16px button beside it carrying the only way in —
          a target no finger lands on, in a drawer a phone opens full height. --%>
    <li
      class={row_classes(false)}
      phx-click={@on_join}
      phx-value-channel={@channel_name}
      data-channel={@channel_name}
      data-joined="false"
      data-testid={"popular-#{@channel_name}"}
      title={
        dngettext(
          "chat",
          "Join %{channel} — %{count} person here",
          "Join %{channel} — %{count} people here",
          @user_count || 0,
          channel: @channel_name,
          count: @user_count || 0
        )
      }
      tabindex="0"
    >
      <span class="chat-conversations-row__icon">
        <Icons.icon_tab_channel class="w-3 h-3" />
      </span>
      <span class="chat-conversations-row__label">{@channel_name}</span>
      <span class="chat-conversations-row__count">({@user_count})</span>
      <.tool_button
        :if={@on_join && !@mobile}
        label={dgettext("chat", "Join %{channel}", channel: @channel_name)}
        variant="flat"
        size="xs"
        class="chat-conversations-row__shortcut"
        phx-click={@on_join}
        phx-value-channel={@channel_name}
        data-testid={"join-#{@channel_name}"}
      >
        <Icons.icon_btn_add class="w-3 h-3" />
      </.tool_button>
    </li>
    """
  end

  @doc false
  attr :name, :string, required: true

  # The visible way to the row's menu. Right-click reaches the same one and a
  # held finger reaches it too, but neither announces itself: one has no touch
  # equivalent at all, the other is invisible until somebody already knows it is
  # there. This button is what a person finds, and finding it is what teaches
  # the two gestures. Coordinates come from the hook, which opens the menu at
  # this element rather than wherever the pointer happened to be.
  defp row_menu_button(assigns) do
    ~H"""
    <.tool_button
      label={dgettext("chat", "Actions for %{name}", name: @name)}
      variant="flat"
      size="xs"
      class="chat-conversations-row__menu"
      data-conversations-menu
      data-testid={"conversations-row-menu-#{@name}"}
      aria-haspopup="menu"
      tabindex="-1"
    >
      <Icons.icon_ellipsis class="w-3.5 h-3.5" />
    </.tool_button>
    """
  end

  @doc false
  attr :name, :string, required: true
  attr :kind, :string, required: true
  attr :muted, :boolean, default: false
  attr :group_call_active, :boolean, default: false
  attr :group_call_summary, :map, default: nil
  attr :p2p_session, :map, default: nil

  # One slot, by precedence. A row that drew every one of these at once left the
  # name — the only thing anybody is reading the row for — as the part that got
  # truncated. A live call outranks a session, and a session outranks the fact
  # that the room is quiet.
  defp row_status(assigns) do
    ~H"""
    <span class="chat-conversations-row__status">
      <.group_call_channel_glyph
        :if={@group_call_active}
        channel={@name}
        summary={@group_call_summary}
        testid={"channel-group-call-glyph-#{@name}"}
      />
      <.p2p_peer_glyph
        :if={!@group_call_active && @p2p_session}
        peer={@name}
        session={@p2p_session}
        testid={"pm-p2p-glyph-#{@name}"}
      />
      <span
        :if={!@group_call_active && is_nil(@p2p_session) && @muted}
        title={dgettext("chat", "Muted")}
        data-testid={"#{@kind}-muted-glyph-#{@name}"}
      >
        <Icons.icon_mute class="w-3 h-3" />
      </span>
    </span>
    """
  end

  @doc false
  attr :mention_count, :integer, default: 0
  attr :unread_count, :integer, default: 0
  attr :unread, :boolean, default: false
  attr :active, :boolean, default: false
  attr :highlight, :boolean, default: false
  attr :mention_testid, :string, required: true
  attr :unread_badge_testid, :string, default: nil
  attr :unread_dot_testid, :string, default: nil

  # Mentions win. Two numbers side by side read as one number typed twice, and
  # of the two only one is worth interrupting for.
  defp row_count(assigns) do
    ~H"""
    <.mention_badge :if={@mention_count > 0} count={@mention_count} testid={@mention_testid} />
    <span
      :if={@mention_count == 0 && @unread && !@active && @unread_count > 0}
      class={unread_badge_classes(@highlight)}
      data-testid={@unread_badge_testid}
    >
      {format_unread_count(@unread_count)}
    </span>
    <span
      :if={@mention_count == 0 && @unread && !@active && @unread_count == 0}
      class="chat-conversations-unread-dot"
      data-testid={@unread_dot_testid}
    />
    """
  end

  # There is no inert row left to describe. A row a click passes through was the
  # thing that made the same list answer four different ways.
  defp row_classes(active) do
    [
      "chat-conversations-row chat-conversations-row--interactive",
      active && "chat-conversations-row--active"
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

  # Open channels and saved ones in one list, each name once. A channel you are
  # in wins the spelling, because that is the one the server just used; the
  # auto-join list only contributes the rooms you are not in yet, in the order
  # it would join them.
  defp channel_rows(assigns) do
    pinned = autojoin_index(assigns.autojoin_entries)
    joined_keys = MapSet.new(assigns.channels, &String.downcase/1)

    fallback_index =
      assigns.channels
      |> Enum.with_index()
      |> Map.new()

    open_rows =
      assigns.channels
      |> Enum.sort_by(fn channel ->
        {-channel_activity_score(assigns, channel), Map.fetch!(fallback_index, channel)}
      end)
      |> Enum.map(fn channel ->
        entry = Map.get(pinned, String.downcase(channel))

        %{
          name: channel,
          joined: true,
          pinned: not is_nil(entry),
          has_key: present?(value(entry, :channel_key))
        }
      end)

    saved_rows =
      assigns.autojoin_entries
      |> Enum.reject(fn entry ->
        MapSet.member?(joined_keys, entry |> entry_channel_name() |> to_key())
      end)
      |> Enum.map(fn entry ->
        %{
          name: entry_channel_name(entry),
          joined: false,
          pinned: true,
          has_key: present?(value(entry, :channel_key))
        }
      end)

    open_rows ++ saved_rows
  end

  defp autojoin_index(entries) do
    Map.new(entries, fn entry -> {entry |> entry_channel_name() |> to_key(), entry} end)
  end

  defp to_key(name) when is_binary(name), do: String.downcase(name)
  defp to_key(_name), do: ""

  defp channel_activity_score(assigns, channel) do
    Map.get(assigns.channel_activity_order || %{}, channel) ||
      if channel_attention?(assigns, channel), do: 1, else: 0
  end

  defp channel_attention?(assigns, channel) do
    unread_count(assigns.unread_counts, channel) > 0 or
      member?(assigns.unread_channels, channel) or
      member?(assigns.highlight_channels, channel) or
      member?(assigns.flash_channels, channel)
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

  # The member count left the row and became the row's tooltip: it is the number
  # on a channel line that changes least and decides least, and it was taking
  # width from the two that do.
  defp channel_row_title(name, _user_count, false = _joined) do
    dgettext("chat", "%{channel} — saved, not open. Opens when you click it.", channel: name)
  end

  defp channel_row_title(name, user_count, _joined) when is_integer(user_count) do
    dngettext(
      "chat",
      "%{channel} — %{count} person here",
      "%{channel} — %{count} people here",
      user_count,
      channel: name,
      count: user_count
    )
  end

  defp channel_row_title(name, _user_count, _joined), do: name

  defp pm_row_title(nick, true = _open_tab), do: nick

  defp pm_row_title(nick, _open_tab) do
    dgettext("chat", "%{nick} — not open. Opens when you click it.", nick: nick)
  end

  defp autojoin_title(true = _has_key) do
    dgettext("chat", "Joined on connect, with a key")
  end

  defp autojoin_title(_has_key), do: dgettext("chat", "Joined on connect")

  defp rail_item_title(label, count) when is_integer(count), do: "#{label}: #{count}"
  defp rail_item_title(label, _count), do: label

  defp nick_color(assigns, nick) do
    if is_function(assigns.nick_color_fn, 1), do: assigns.nick_color_fn.(nick)
  end

  defp entry_channel_name(entry), do: value(entry, :channel_name)

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_value), do: false

  defp p2p_session_for_pm(%{p2p_pm_sessions: sessions}, nick)
       when is_map(sessions) and is_binary(nick),
       do: Map.get(sessions, String.downcase(nick))

  defp p2p_session_for_pm(_assigns, _nick), do: nil

  # Nil-safe because the session it reads is absent more often than present.
  defp value(nil, _key), do: nil
  defp value(map, key) when is_map(map) and is_atom(key), do: Map.get(map, key)
end

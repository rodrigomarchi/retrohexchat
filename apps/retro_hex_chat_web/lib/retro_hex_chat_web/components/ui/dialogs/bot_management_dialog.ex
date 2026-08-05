defmodule RetroHexChatWeb.Components.UI.BotManagementDialog do
  @moduledoc """
  Bot Management: a roster, and the bot it drills into.

  The window shows one screen at a time. `selected == nil` is the roster — every
  bot with what an operator asks before clicking anything: whether its process is
  alive, what it is for, where it works, what it can do. A selection replaces the
  roster with that bot's detail; going back clears the selection.

  Nothing here writes. Configuration is applied through `/bot set`, and each
  capability panel names the key it would take, so what is read on screen and
  what is typed in the console are the same word.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.ListStates

  import RetroHexChatWeb.Components.UI.Dialog
  import RetroHexChatWeb.Components.UI.Tabs
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Separator

  alias RetroHexChat.Bots.Capabilities
  alias RetroHexChat.Chat.Content
  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  # Long enough that a description is a description and not a headline, short
  # enough that one bot cannot push the next one off the roster.
  @description_preview 120

  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :bots, :list, default: []

  attr :running, :list,
    default: [],
    doc: "Nicknames with a live process, so the roster can say which bots are actually up"

  attr :selected, :any, default: nil, doc: "nil shows the roster; a bot shows its detail"
  attr :channels, :list, default: []
  attr :commands, :list, default: []
  attr :events, :any, default: [], doc: "Stream of the event log"

  attr :events_state, :map,
    default: nil,
    doc: "PaginatedList.State for the event log; nil renders the log without pagination"

  attr :island_target, :any, default: nil, doc: "phx-target of the owning island"
  attr :stats, :any, default: nil
  attr :is_admin, :boolean, default: false
  attr :on_close, :any, default: nil
  attr :windowed, :boolean, default: false

  @spec bot_management_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def bot_management_dialog(assigns) do
    ~H"""
    <div
      :if={@windowed}
      id={"#{@id}-content"}
      data-testid="bot-management-panel"
      class="bm-dialog flex h-full min-h-0 flex-col"
    >
      <.bot_management_body {assigns} />
    </div>

    <.dialog :if={not @windowed} id={@id} show={@show} class="max-w-2xl">
      <.dialog_header id={@id} title={dgettext("dialogs", "Bot Management")}>
        <:icon><Icons.icon_dialog_bot_management class="w-[16px] h-[16px]" /></:icon>
      </.dialog_header>
      <.dialog_body class="min-h-[400px]">
        <.bot_management_body {assigns} />
      </.dialog_body>
      <.dialog_footer>
        <.button type="button" phx-click={@on_close}>
          <:icon><Icons.icon_checkmark class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Close")}
        </.button>
      </.dialog_footer>
    </.dialog>
    """
  end

  defp bot_management_body(assigns) do
    ~H"""
    <div class="bm-body flex min-h-0 flex-1 flex-col">
      <.bot_roster
        :if={@selected == nil}
        bots={@bots}
        running={@running}
        is_admin={@is_admin}
      />
      <.bot_detail
        :if={@selected != nil}
        selected={@selected}
        running={@running}
        channels={@channels}
        commands={@commands}
        events={@events}
        events_state={@events_state}
        island_target={@island_target}
        stats={@stats}
        is_admin={@is_admin}
      />
    </div>
    """
  end

  # ── Roster ───────────────────────────────────────────────

  attr :bots, :list, required: true
  attr :running, :list, default: []
  attr :is_admin, :boolean, default: false

  @spec bot_roster(map()) :: Phoenix.LiveView.Rendered.t()
  defp bot_roster(assigns) do
    ~H"""
    <div class="bm-roster flex min-h-0 flex-1 flex-col">
      <div class="bm-roster-head">
        <span class="bm-roster-title">
          <Icons.icon_btn_bot_management class="w-[16px] h-[16px]" />
          {dgettext("dialogs", "Bots")}
          <span class="bm-roster-count" data-testid="bot-count">{length(@bots)}</span>
        </span>
        <.button
          :if={@is_admin}
          type="button"
          size="sm"
          phx-click="open_new_bot_dialog"
          class="bm-action-button"
        >
          <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "New")}
        </.button>
      </div>

      <div class="bm-roster-scroll min-h-0 flex-1 overflow-y-auto retro-scrollbar">
        <p :if={@bots == []} class="bm-empty">
          {dgettext("dialogs", "No bots yet. Create one and it will appear here.")}
        </p>

        <ul :if={@bots != []} class="bm-roster-list" data-testid="bot-list">
          <li
            :for={bot <- @bots}
            class="bm-roster-row"
            phx-click="bot_select"
            phx-value-name={bot_name(bot)}
            data-testid={"bot-item-#{bot_name(bot)}"}
            role="button"
            tabindex="0"
          >
            <span
              class={["bm-dot", bot_state_class(bot, @running)]}
              title={bot_state_label(bot, @running)}
              aria-hidden="true"
            >
            </span>

            <div class="bm-roster-main">
              <div class="bm-roster-line">
                <span class="bm-roster-name">{bot_name(bot)}</span>
                <span :if={bot_nickname(bot) != bot_name(bot)} class="bm-roster-nick">
                  {bot_nickname(bot)}
                </span>
                <span class={["bm-roster-state", bot_state_text_class(bot, @running)]}>
                  {bot_state_label(bot, @running)}
                </span>
              </div>

              <p class="bm-roster-desc">
                {bot_description(bot) || dgettext("dialogs", "No description")}
              </p>

              <div class="bm-roster-tags">
                <span :for={channel <- bot_channel_names(bot)} class="bm-chip bm-chip--channel">
                  {channel}
                </span>
                <span
                  :for={cap <- enabled_capability_names(bot)}
                  class="bm-chip bm-chip--capability"
                >
                  {cap_display_name(cap)}
                </span>
                <span :if={enabled_capability_names(bot) == []} class="bm-chip bm-chip--muted">
                  {dgettext("dialogs", "No capabilities")}
                </span>
              </div>
            </div>

            <div class="bm-roster-meta">
              <span class="bm-roster-metric">
                {dngettext(
                  "dialogs",
                  "%{count} command",
                  "%{count} commands",
                  bot_command_count(bot)
                )}
              </span>
              <Icons.icon_chevron_right class="w-[14px] h-[14px] bm-roster-chevron" />
            </div>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  # ── Detail ───────────────────────────────────────────────

  attr :selected, :any, required: true
  attr :running, :list, default: []
  attr :channels, :list, default: []
  attr :commands, :list, default: []
  attr :events, :any, default: []
  attr :events_state, :map, default: nil
  attr :island_target, :any, default: nil
  attr :stats, :any, default: nil
  attr :is_admin, :boolean, default: false

  @spec bot_detail(map()) :: Phoenix.LiveView.Rendered.t()
  defp bot_detail(assigns) do
    ~H"""
    <div class="bm-detail flex min-h-0 flex-1 flex-col">
      <div class="bm-detail-head">
        <.button
          type="button"
          size="sm"
          phx-click="bot_back"
          data-testid="bot-back"
          class="bm-action-button"
        >
          <:icon><Icons.icon_chevron_left class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Bots")}
        </.button>

        <span
          class={["bm-dot", bot_state_class(@selected, @running)]}
          title={bot_state_label(@selected, @running)}
          aria-hidden="true"
        >
        </span>

        <div class="bm-detail-identity">
          <div class="bm-detail-line">
            <span class="bm-detail-name">{bot_name(@selected)}</span>
            <span :if={bot_nickname(@selected) != bot_name(@selected)} class="bm-roster-nick">
              {bot_nickname(@selected)}
            </span>
            <span class={["bm-roster-state", bot_state_text_class(@selected, @running)]}>
              {bot_state_label(@selected, @running)}
            </span>
          </div>
          <p class="bm-detail-desc">
            {bot_description(@selected) || dgettext("dialogs", "No description")}
          </p>
        </div>

        <div :if={@is_admin} class="bm-detail-actions">
          <.button
            type="button"
            size="sm"
            phx-click="bot_toggle_enabled"
            phx-value-name={bot_name(@selected)}
            data-testid={"bot-toggle-enabled-#{bot_name(@selected)}"}
            class="bm-action-button"
          >
            <:icon><.bot_status_toggle_icon selected={@selected} /></:icon>
            {bot_status_toggle_label(@selected)}
          </.button>
          <.button
            type="button"
            size="sm"
            variant="destructive"
            phx-click="bot_delete"
            phx-value-name={bot_name(@selected)}
            data-testid={"bot-delete-#{bot_name(@selected)}"}
            class="bm-action-button"
          >
            <:icon><Icons.icon_trash class="w-[14px] h-[14px]" /></:icon>
            {dgettext("dialogs", "Delete")}
          </.button>
        </div>
      </div>

      <.tabs id="bot-tabs" default="general" class="bm-tabs flex min-h-0 flex-1 flex-col">
        <div class="bm-tabs-shell">
          <.tabs_list class="bm-main-tabs gap-0">
            <.tabs_trigger builder={%{id: "bot-tabs", default: "general"}} value="general">
              <:icon><Icons.icon_tab_general class="w-[16px] h-[16px]" /></:icon>
              {dgettext("dialogs", "General")}
            </.tabs_trigger>
            <.tabs_trigger builder={%{id: "bot-tabs", default: "general"}} value="capabilities">
              <:icon><Icons.icon_tab_control class="w-[16px] h-[16px]" /></:icon>
              {dgettext("dialogs", "Capabilities")}
            </.tabs_trigger>
            <.tabs_trigger builder={%{id: "bot-tabs", default: "general"}} value="channels">
              <:icon><Icons.icon_tab_channel class="w-[16px] h-[16px]" /></:icon>
              {dgettext("dialogs", "Channels")}
            </.tabs_trigger>
            <.tabs_trigger builder={%{id: "bot-tabs", default: "general"}} value="commands">
              <:icon><Icons.icon_tab_commands class="w-[16px] h-[16px]" /></:icon>
              {dgettext("dialogs", "Commands")}
            </.tabs_trigger>
            <.tabs_trigger builder={%{id: "bot-tabs", default: "general"}} value="events">
              <:icon><Icons.icon_clock class="w-[16px] h-[16px]" /></:icon>
              {dgettext("dialogs", "Events")}
            </.tabs_trigger>
          </.tabs_list>
        </div>

        <.tabs_content value="general" class="bm-tab-pane">
          <.general_tab selected={@selected} running={@running} stats={@stats} channels={@channels} />
        </.tabs_content>

        <.tabs_content value="capabilities" class="bm-tab-pane">
          <.capabilities_tab selected={@selected} is_admin={@is_admin} />
        </.tabs_content>

        <.tabs_content value="channels" class="bm-tab-pane">
          <.channels_tab selected={@selected} channels={@channels} is_admin={@is_admin} />
        </.tabs_content>

        <.tabs_content value="commands" class="bm-tab-pane">
          <.commands_tab selected={@selected} commands={@commands} is_admin={@is_admin} />
        </.tabs_content>

        <.tabs_content value="events" class="bm-tab-pane">
          <.events_tab
            events={@events}
            events_state={@events_state}
            island_target={@island_target}
          />
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  # ── General tab ──────────────────────────────────────────

  attr :selected, :any, required: true
  attr :running, :list, default: []
  attr :stats, :any, default: nil
  attr :channels, :list, default: []

  @spec general_tab(map()) :: Phoenix.LiveView.Rendered.t()
  defp general_tab(assigns) do
    ~H"""
    <div class="bm-pane">
      <section class="bm-section">
        <h3 class="bm-section-title">{dgettext("dialogs", "Runtime")}</h3>
        <dl class="bm-facts">
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Process")}</dt>
            <dd class={bot_state_text_class(@selected, @running)}>
              {bot_state_label(@selected, @running)}
            </dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Uptime")}</dt>
            <dd data-testid="bot-uptime">{stat_uptime(@stats)}</dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Messages handled")}</dt>
            <dd data-testid="bot-messages">{stat_count(@stats, :messages)}</dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Commands processed")}</dt>
            <dd data-testid="bot-commands">{stat_count(@stats, :commands)}</dd>
          </div>
        </dl>
        <p :if={@stats == nil} class="bm-hint">
          {dgettext(
            "dialogs",
            "No process is running for this bot, so it is not answering anyone."
          )}
        </p>
      </section>

      <.separator />

      <section class="bm-section">
        <h3 class="bm-section-title">{dgettext("dialogs", "Identity")}</h3>
        <dl class="bm-facts">
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Name")}</dt>
            <dd>{bot_name(@selected)}</dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Nickname")}</dt>
            <dd>{bot_nickname(@selected)}</dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Command prefix")}</dt>
            <dd class="font-mono" data-testid="bot-prefix">{bot_prefix(@selected)}</dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Cooldown")}</dt>
            <dd>{format_ms(Map.get(@selected, :cooldown_ms))}</dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Created by")}</dt>
            <dd>{Map.get(@selected, :created_by) || "—"}</dd>
          </div>
          <div class="bm-fact">
            <dt>{dgettext("dialogs", "Created")}</dt>
            <dd>{format_timestamp(Map.get(@selected, :inserted_at))}</dd>
          </div>
        </dl>
      </section>

      <.separator />

      <section class="bm-section">
        <h3 class="bm-section-title">{dgettext("dialogs", "Capabilities")}</h3>
        <div class="bm-roster-tags">
          <span
            :for={{cap, enabled} <- capability_states(@selected)}
            class={["bm-chip", if(enabled, do: "bm-chip--capability", else: "bm-chip--muted")]}
          >
            {cap_display_name(cap)}
            <span :if={not enabled} class="bm-chip-note">{dgettext("dialogs", "off")}</span>
          </span>
          <span :if={capability_states(@selected) == []} class="bm-chip bm-chip--muted">
            {dgettext("dialogs", "No capabilities configured")}
          </span>
        </div>
      </section>

      <.separator />

      <section class="bm-section">
        <h3 class="bm-section-title">{dgettext("dialogs", "Channels")}</h3>
        <div class="bm-roster-tags">
          <span :for={ch <- @channels} class="bm-chip bm-chip--channel">{bot_channel_name(ch)}</span>
          <span :if={@channels == []} class="bm-chip bm-chip--muted">
            {dgettext("dialogs", "No channels assigned")}
          </span>
        </div>
      </section>
    </div>
    """
  end

  # ── Capabilities tab ─────────────────────────────────────

  attr :selected, :any, required: true
  attr :is_admin, :boolean, default: false

  @spec capabilities_tab(map()) :: Phoenix.LiveView.Rendered.t()
  defp capabilities_tab(assigns) do
    caps = (assigns.selected && Map.get(assigns.selected, :capabilities)) || %{}
    assigns = assign(assigns, caps: caps, cap_names: Enum.sort(Map.keys(caps)))

    ~H"""
    <div class="bm-pane">
      <p :if={@cap_names == []} class="bm-empty">
        {dgettext("dialogs", "No configurable capabilities enabled.")}
      </p>

      <p :if={@is_admin and @cap_names != []} class="bm-hint">
        {dgettext("dialogs", "Change these with /bot set %{bot} <key> <value> in the console.",
          bot: bot_name(@selected)
        )}
      </p>

      <section
        :for={cap_name <- @cap_names}
        class="bm-cap"
        data-testid={"bot-capability-#{cap_name}"}
      >
        <header class="bm-cap-head">
          <span class="bm-cap-name">{cap_display_name(cap_name)}</span>
          <span class={[
            "bm-cap-state",
            if(cap_enabled?(@caps[cap_name]), do: "bm-cap-state--on", else: "bm-cap-state--off")
          ]}>
            {if cap_enabled?(@caps[cap_name]),
              do: dgettext("dialogs", "Enabled"),
              else: dgettext("dialogs", "Disabled")}
          </span>
          <.button
            :if={@is_admin}
            type="button"
            size="sm"
            phx-click="bot_toggle_capability"
            phx-value-capability={cap_name}
            phx-value-bot_name={bot_name(@selected)}
            data-testid={"toggle-cap-#{cap_name}"}
            class="bm-action-button"
          >
            <:icon>
              <Icons.icon_cancel
                :if={cap_enabled?(@caps[cap_name])}
                class="w-[14px] h-[14px]"
              />
              <Icons.icon_checkmark
                :if={not cap_enabled?(@caps[cap_name])}
                class="w-[14px] h-[14px]"
              />
            </:icon>
            {if cap_enabled?(@caps[cap_name]),
              do: dgettext("dialogs", "Disable"),
              else: dgettext("dialogs", "Enable")}
          </.button>
        </header>

        <p :if={cap_description(cap_name)} class="bm-cap-desc">{cap_description(cap_name)}</p>
        <p :if={Capabilities.stub?(cap_name)} class="bm-hint">
          {dgettext("dialogs", "Declared but not implemented — this capability answers nothing.")}
        </p>

        <dl :if={cap_config_fields(@caps[cap_name]) != []} class="bm-config">
          <div :for={{key, value} <- cap_config_fields(@caps[cap_name])} class="bm-config-row">
            <dt class="bm-config-key">{key}</dt>
            <dd class={["bm-config-value", if(long_text?(value), do: "bm-config-value--block")]}>
              {render_cap_value(key, value)}
            </dd>
          </div>
        </dl>

        <.rss_feeds
          :if={cap_name == "rss"}
          feeds={Map.get(@caps["rss"] || %{}, "feeds", [])}
          bot_name={bot_name(@selected)}
          is_admin={@is_admin}
        />
      </section>
    </div>
    """
  end

  attr :feeds, :list, default: []
  attr :bot_name, :string, required: true
  attr :is_admin, :boolean, default: false

  # "1 item" tells an administrator nothing about a feed list. What they need is
  # which feed goes to which room, whether the last poll worked, and why it did
  # not — the question "is it running?" answered without opening the logs.
  @spec rss_feeds(map()) :: Phoenix.LiveView.Rendered.t()
  defp rss_feeds(assigns) do
    ~H"""
    <div class="bm-feeds" data-testid="rss-feeds">
      <h4 class="bm-subsection-title">{dgettext("dialogs", "Feeds")}</h4>

      <p :if={@feeds == []} class="bm-empty">
        {dgettext("dialogs", "No feeds yet. Add one and it will start polling.")}
      </p>

      <div :if={@feeds != []} class="bm-object-list" role="list">
        <article
          :for={feed <- @feeds}
          class="bm-object-entry"
          role="listitem"
          data-testid={"rss-feed-#{feed["id"]}"}
        >
          <div class="bm-object-body">
            <div class="bm-object-primary">
              <span class="bm-object-label">{dgettext("dialogs", "Feed")}</span>
              <span class="bm-object-value">
                {feed["title"] || truncate(feed["url"], 48)}
              </span>
            </div>
            <div class="bm-object-meta">
              <span class="bm-object-label">{dgettext("dialogs", "Posts to")}</span>
              <span class="bm-object-value">{feed["channel"]}</span>
            </div>
            <div class="bm-object-meta">
              <span class="bm-object-label">{dgettext("dialogs", "Last checked")}</span>
              <span class="bm-object-value">
                {feed["last_polled_at"] || dgettext("dialogs", "never")}
              </span>
            </div>
            <div :if={feed["last_error"]} class="bm-object-meta" data-testid="rss-feed-error">
              <span class="bm-object-label">{dgettext("dialogs", "Problem")}</span>
              <span class="bm-object-value bm-text-danger">{feed["last_error"]}</span>
            </div>
          </div>
          <button
            :if={@is_admin}
            type="button"
            class="bm-link-danger bm-object-action text-xs hover:underline"
            phx-click="bot_rss_remove_feed"
            phx-value-bot_name={@bot_name}
            phx-value-feed_id={feed["id"]}
            data-testid={"rss-remove-#{feed["id"]}"}
          >
            {dgettext("dialogs", "Remove")}
          </button>
        </article>
      </div>

      <form
        :if={@is_admin}
        id="rss-add-feed-form"
        phx-submit="bot_rss_add_feed"
        class="bm-action-form"
      >
        <input type="hidden" name="bot_name" value={@bot_name} />
        <input
          type="url"
          name="url"
          required
          placeholder="https://example.com/feed.xml"
          class="bm-action-input flex-1 shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
          autocomplete="off"
          data-testid="rss-feed-url"
        />
        <input
          type="text"
          name="channel"
          required
          placeholder="#news"
          class="bm-action-input w-[120px] shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
          autocomplete="off"
          data-testid="rss-feed-channel"
        />
        <.button type="submit" size="sm" class="bm-action-button" data-testid="rss-add-feed">
          <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Add")}
        </.button>
      </form>
    </div>
    """
  end

  # ── Channels tab ─────────────────────────────────────────

  attr :selected, :any, required: true
  attr :channels, :list, default: []
  attr :is_admin, :boolean, default: false

  @spec channels_tab(map()) :: Phoenix.LiveView.Rendered.t()
  defp channels_tab(assigns) do
    ~H"""
    <div class="bm-pane">
      <p :if={@channels == []} class="bm-empty">
        {dgettext("dialogs", "No channels assigned")}
      </p>

      <div :if={@channels != []} class="bm-object-list" role="list">
        <article :for={ch <- @channels} class="bm-object-entry" role="listitem">
          <div class="bm-object-body">
            <div class="bm-object-primary">
              <span class="bm-object-label">{dgettext("dialogs", "Channel")}</span>
              <span class="bm-object-value">{bot_channel_name(ch)}</span>
            </div>
            <div class="bm-object-meta">
              <span class="bm-object-label">{dgettext("dialogs", "Status")}</span>
              <span class="bm-object-value">{channel_status(ch)}</span>
            </div>
          </div>
          <button
            :if={@is_admin}
            type="button"
            class="bm-link-danger bm-object-action text-xs hover:underline"
            phx-click="bot_remove_channel"
            phx-value-channel={bot_channel_name(ch)}
            phx-value-bot_name={bot_name(@selected)}
          >
            {dgettext("dialogs", "Remove")}
          </button>
        </article>
      </div>

      <form :if={@is_admin} phx-submit="bot_add_channel" class="bm-action-form">
        <input type="hidden" name="bot_name" value={bot_name(@selected)} />
        <input
          type="text"
          name="channel"
          placeholder="#channel"
          class="bm-action-input flex-1 shadow-retro-sunken bg-white px-retro-4 py-retro-2 text-sm"
          autocomplete="off"
        />
        <.button type="submit" size="sm" class="bm-action-button">
          <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Add")}
        </.button>
      </form>
    </div>
    """
  end

  # ── Commands tab ─────────────────────────────────────────

  attr :selected, :any, required: true
  attr :commands, :list, default: []
  attr :is_admin, :boolean, default: false

  @spec commands_tab(map()) :: Phoenix.LiveView.Rendered.t()
  defp commands_tab(assigns) do
    ~H"""
    <div class="bm-pane">
      <p :if={@commands == []} class="bm-empty">
        {dgettext("dialogs", "No custom commands")}
      </p>

      <div :if={@commands != []} class="bm-object-list" role="list">
        <article :for={cmd <- @commands} class="bm-object-entry" role="listitem">
          <div class="bm-object-body">
            <div class="bm-object-primary">
              <span class="bm-object-value font-mono">
                {command_invocation(@selected, cmd)}
              </span>
            </div>
            <div :if={Map.get(cmd, :description)} class="bm-object-meta">
              <span class="bm-object-value">{Map.get(cmd, :description)}</span>
            </div>
            <div class="bm-object-meta">
              <span class="bm-object-label">{dgettext("dialogs", "Replies")}</span>
              <span class="bm-object-value">{rich_text(Map.get(cmd, :response, ""))}</span>
            </div>
          </div>
          <button
            :if={@is_admin}
            type="button"
            class="bm-link-danger bm-object-action text-xs hover:underline"
            phx-click="bot_remove_command"
            phx-value-trigger={Map.get(cmd, :trigger, "")}
            phx-value-bot_name={bot_name(@selected)}
          >
            {dgettext("dialogs", "Remove")}
          </button>
        </article>
      </div>

      <div :if={@is_admin} class="bm-action-row">
        <.button type="button" size="sm" phx-click="open_add_command_dialog" class="bm-action-button">
          <:icon><Icons.icon_btn_add class="w-[14px] h-[14px]" /></:icon>
          {dgettext("dialogs", "Add")}
        </.button>
      </div>
    </div>
    """
  end

  # ── Events tab ───────────────────────────────────────────

  attr :events, :any, default: []
  attr :events_state, :map, default: nil
  attr :island_target, :any, default: nil

  @spec events_tab(map()) :: Phoenix.LiveView.Rendered.t()
  defp events_tab(assigns) do
    ~H"""
    <div class="bm-pane">
      <div
        id="bm-events-list"
        class="bm-events-list shadow-retro-sunken bg-white overflow-y-auto p-retro-2 retro-scrollbar"
        phx-hook="InfiniteScrollHook"
        phx-update="stream"
        data-edge="bottom"
        data-target={@island_target}
        data-event="load_more"
        data-has-more={to_string(State.more?(@events_state))}
        data-loading={to_string(State.loading?(@events_state))}
      >
        <div :for={{dom_id, event} <- @events} id={dom_id} class="bm-event-row">
          <span class="bm-event-time">{event_time(event)}</span>
          <span class="bm-event-message">{event_description(event)}</span>
          <span :if={event_channel(event)} class="bm-event-channel">{event_channel(event)}</span>
        </div>
      </div>
      <.list_load_more_button
        :if={State.more?(@events_state)}
        target={@island_target}
        loading={State.loading?(@events_state)}
        testid="bot-events-load-more"
      />
      <.list_announcer state={@events_state} />
      <.list_error_retry
        :if={State.error?(@events_state)}
        target={@island_target}
        on_retry="load_more"
        text={dgettext("dialogs", "Could not load more events.")}
      />
      <.list_end_marker :if={State.exhausted?(@events_state)} variant={:start} />
    </div>
    """
  end

  # ── Bot readers ──────────────────────────────────────────
  #
  # The component is handed `Bot` structs from the island and plain maps from the
  # showcase and the tests, so every field is read defensively and an unloaded
  # association reads as absent rather than crashing the window.

  @spec bot_name(map()) :: String.t()
  defp bot_name(bot), do: Map.get(bot, :name, "")

  @spec bot_nickname(map()) :: String.t()
  defp bot_nickname(bot), do: Map.get(bot, :nickname) || bot_name(bot)

  @spec bot_prefix(map()) :: String.t()
  defp bot_prefix(bot), do: Map.get(bot, :command_prefix) || "!"

  @spec bot_description(map()) :: String.t() | nil
  defp bot_description(bot) do
    case Map.get(bot, :description) do
      nil -> nil
      "" -> nil
      text -> truncate(text, @description_preview)
    end
  end

  @spec bot_enabled?(map()) :: boolean()
  defp bot_enabled?(bot), do: Map.get(bot, :enabled, true)

  @spec loaded(any()) :: list()
  defp loaded(list) when is_list(list), do: list
  defp loaded(_not_loaded), do: []

  @spec bot_channel_names(map()) :: [String.t()]
  defp bot_channel_names(bot) do
    bot
    |> Map.get(:channel_configs)
    |> loaded()
    |> Enum.map(&bot_channel_name/1)
    |> Enum.reject(&(&1 == ""))
  end

  @spec bot_command_count(map()) :: non_neg_integer()
  defp bot_command_count(bot) do
    bot |> Map.get(:custom_commands) |> loaded() |> length()
  end

  @spec capability_states(map()) :: [{String.t(), boolean()}]
  defp capability_states(bot) do
    case Map.get(bot, :capabilities) do
      caps when is_map(caps) ->
        caps |> Enum.map(fn {name, config} -> {name, cap_enabled?(config)} end) |> Enum.sort()

      caps when is_list(caps) ->
        Enum.map(caps, &{&1, true})

      _other ->
        []
    end
  end

  @spec enabled_capability_names(map()) :: [String.t()]
  defp enabled_capability_names(bot) do
    bot |> capability_states() |> Enum.filter(&elem(&1, 1)) |> Enum.map(&elem(&1, 0))
  end

  # ── Process state ────────────────────────────────────────
  #
  # Three states, not two: a bot can be enabled and still have no process — after
  # a crash, or before the loader reached it — and that is exactly the case an
  # operator opens this window to find.

  @spec bot_state(map(), list()) :: :disabled | :running | :stopped
  defp bot_state(bot, running) do
    cond do
      not bot_enabled?(bot) -> :disabled
      bot_nickname(bot) in running -> :running
      true -> :stopped
    end
  end

  @spec bot_state_label(map(), list()) :: String.t()
  defp bot_state_label(bot, running) do
    case bot_state(bot, running) do
      :running -> dgettext("dialogs", "Running")
      :stopped -> dgettext("dialogs", "Stopped")
      :disabled -> dgettext("dialogs", "Disabled")
    end
  end

  @spec bot_state_class(map(), list()) :: String.t()
  defp bot_state_class(bot, running) do
    case bot_state(bot, running) do
      :running -> "bm-dot--running"
      :stopped -> "bm-dot--stopped"
      :disabled -> "bm-dot--disabled"
    end
  end

  @spec bot_state_text_class(map(), list()) :: String.t()
  defp bot_state_text_class(bot, running) do
    case bot_state(bot, running) do
      :running -> "bm-text-ok"
      :stopped -> "bm-text-warn"
      :disabled -> "bm-text-danger"
    end
  end

  @spec bot_status_toggle_label(map()) :: String.t()
  defp bot_status_toggle_label(bot) do
    if bot_enabled?(bot),
      do: dgettext("dialogs", "Disable"),
      else: dgettext("dialogs", "Enable")
  end

  attr :selected, :map, required: true

  @spec bot_status_toggle_icon(map()) :: Phoenix.LiveView.Rendered.t()
  defp bot_status_toggle_icon(assigns) do
    ~H"""
    <%= if bot_enabled?(@selected) do %>
      <Icons.icon_cancel class="w-[14px] h-[14px]" />
    <% else %>
      <Icons.icon_checkmark class="w-[14px] h-[14px]" />
    <% end %>
    """
  end

  # ── Runtime statistics ───────────────────────────────────
  #
  # `nil` stats mean no process answered, which is not the same as a bot that has
  # handled nothing. The two read differently on purpose.

  @spec stat_count(map() | nil, atom()) :: String.t()
  defp stat_count(nil, _key), do: "—"
  defp stat_count(stats, key), do: stats |> Map.get(key, 0) |> to_string()

  @spec stat_uptime(map() | nil) :: String.t()
  defp stat_uptime(nil), do: "—"

  defp stat_uptime(stats) do
    case Map.get(stats, :uptime) do
      nil -> "—"
      uptime -> uptime
    end
  end

  # ── Capability presentation ──────────────────────────────

  @spec cap_enabled?(map() | nil) :: boolean()
  defp cap_enabled?(nil), do: false
  defp cap_enabled?(config) when is_map(config), do: Map.get(config, "enabled", true)
  defp cap_enabled?(_config), do: true

  @spec cap_description(String.t()) :: String.t() | nil
  defp cap_description(cap_name), do: Capabilities.describe(cap_name)

  @spec cap_display_name(String.t()) :: String.t()
  defp cap_display_name("dice"), do: dgettext("dialogs", "Dice")
  defp cap_display_name("moderation"), do: dgettext("dialogs", "Moderation")
  defp cap_display_name("trivia"), do: dgettext("dialogs", "Trivia")
  defp cap_display_name("scheduler"), do: dgettext("dialogs", "Scheduler")
  defp cap_display_name("rss"), do: dgettext("dialogs", "RSS")
  defp cap_display_name("greeter"), do: dgettext("dialogs", "Greeter")
  defp cap_display_name("mention"), do: dgettext("dialogs", "Mention")
  defp cap_display_name("help"), do: dgettext("dialogs", "Help")
  defp cap_display_name("custom_commands"), do: dgettext("dialogs", "Custom commands")
  defp cap_display_name(other), do: other |> String.replace("_", " ") |> String.capitalize()

  # The feed list has its own panel; the generic key/value row would render it
  # as "1 item".
  @spec cap_config_fields(map() | nil) :: [{String.t(), any()}]
  defp cap_config_fields(nil), do: []

  defp cap_config_fields(config) do
    config
    |> Map.drop(["enabled", "feeds"])
    |> Enum.sort_by(&elem(&1, 0))
  end

  # Configuration keys are identifiers, not prose: `greeting_delivery` is the
  # word typed into `/bot set`, and translating it would leave the reader with a
  # label that matches nothing they can type.
  @spec render_cap_value(String.t(), any()) :: any()
  defp render_cap_value(_key, nil), do: "—"
  defp render_cap_value(_key, true), do: dgettext("dialogs", "Yes")
  defp render_cap_value(_key, false), do: dgettext("dialogs", "No")
  defp render_cap_value(_key, []), do: dgettext("dialogs", "none")

  defp render_cap_value(key, value) when is_integer(value) do
    cond do
      String.ends_with?(key, "_sec") -> format_seconds(value)
      String.ends_with?(key, "_min") -> format_seconds(value * 60)
      String.ends_with?(key, "_ms") -> format_ms(value)
      true -> to_string(value)
    end
  end

  defp render_cap_value(_key, value) when is_binary(value), do: rich_text(value)

  defp render_cap_value(_key, value) when is_list(value) do
    if Enum.all?(value, &is_binary/1) do
      Enum.join(value, ", ")
    else
      dngettext("dialogs", "%{count} entry", "%{count} entries", length(value))
    end
  end

  defp render_cap_value(_key, value) when is_map(value),
    do: dngettext("dialogs", "%{count} entry", "%{count} entries", map_size(value))

  defp render_cap_value(_key, value), do: to_string(value)

  @spec long_text?(any()) :: boolean()
  defp long_text?(value) when is_binary(value), do: String.length(value) > 40
  defp long_text?(_value), do: false

  # mIRC control bytes are invisible to the browser, which leaves their colour
  # digits behind as text ("04 [Cassandra]"). Everything a bot was configured to
  # say goes through the same renderer the chat itself uses.
  @spec rich_text(String.t() | nil) :: Phoenix.HTML.safe()
  defp rich_text(nil), do: {:safe, ""}
  defp rich_text(""), do: {:safe, ""}
  defp rich_text(text) when is_binary(text), do: Content.render_html(text, :irc)

  # ── Channels, commands, events ───────────────────────────

  @spec channel_status(map() | String.t()) :: String.t()
  defp channel_status(ch) do
    status =
      cond do
        is_map(ch) and Map.has_key?(ch, :status) -> Map.get(ch, :status)
        is_map(ch) and Map.get(ch, :enabled) == false -> "parted"
        true -> "joined"
      end

    case status do
      "joined" -> dgettext("dialogs", "joined")
      "parted" -> dgettext("dialogs", "parted")
      other -> other
    end
  end

  @spec bot_channel_name(map() | String.t()) :: String.t()
  defp bot_channel_name(ch) when is_binary(ch), do: ch
  defp bot_channel_name(%{name: name}) when is_binary(name), do: name
  defp bot_channel_name(%{channel_name: name}) when is_binary(name), do: name
  defp bot_channel_name(_ch), do: ""

  # How the command is actually typed in a channel, which is what an operator
  # came to check — the trigger alone is missing the prefix and the bot's name.
  @spec command_invocation(map(), map()) :: String.t()
  defp command_invocation(bot, cmd) do
    bot_prefix(bot) <> bot_name(bot) <> " " <> Map.get(cmd, :trigger, "")
  end

  @spec event_time(map()) :: String.t()
  defp event_time(event) do
    case Map.get(event, :inserted_at) do
      %DateTime{} = at -> TimeFormatter.format_relative(at)
      _other -> Map.get(event, :timestamp, "")
    end
  end

  # Event types are written by the runtime as identifiers ("channel_user_joined",
  # "message_response"). They are shown as words, without pretending the log
  # holds a sentence it never wrote.
  @spec event_description(map()) :: String.t()
  defp event_description(event) do
    case Map.get(event, :event_type) do
      type when is_binary(type) -> type |> String.replace("_", " ")
      _other -> Map.get(event, :message, "")
    end
  end

  @spec event_channel(map()) :: String.t() | nil
  defp event_channel(event) do
    case Map.get(event, :channel) do
      channel when is_binary(channel) and channel != "" -> channel
      _other -> nil
    end
  end

  # ── Formatting ───────────────────────────────────────────

  @spec truncate(String.t() | nil, pos_integer()) :: String.t()
  defp truncate(nil, _max), do: ""

  defp truncate(text, max) do
    if String.length(text) > max, do: String.slice(text, 0, max - 1) <> "…", else: text
  end

  # Units stay as symbols rather than words: they sit in a dense column of
  # numbers, and "43200 s" is worse than "12h" in every language.
  @spec format_seconds(integer()) :: String.t()
  defp format_seconds(seconds) when seconds < 60, do: "#{seconds}s"
  defp format_seconds(seconds) when seconds < 3600, do: "#{div(seconds, 60)}min"
  defp format_seconds(seconds) when seconds < 86_400, do: "#{div(seconds, 3600)}h"
  defp format_seconds(seconds), do: "#{div(seconds, 86_400)}d"

  @spec format_ms(integer() | nil) :: String.t()
  defp format_ms(nil), do: "—"
  defp format_ms(ms) when ms < 1000, do: "#{ms}ms"
  defp format_ms(ms), do: :erlang.float_to_binary(ms / 1000, decimals: 1) <> "s"

  @spec format_timestamp(DateTime.t() | NaiveDateTime.t() | nil) :: String.t()
  defp format_timestamp(%DateTime{} = at), do: TimeFormatter.format_relative(at)
  defp format_timestamp(_other), do: "—"
end

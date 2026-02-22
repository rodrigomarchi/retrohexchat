defmodule RetroHexChatWeb.Components.BotManagementDialog do
  @moduledoc """
  Win98-styled Bot Management dialog with split-view layout.
  Lists bots on the left, details/tabs on the right.
  """
  use Phoenix.Component

  import Phoenix.HTML, only: [raw: 1]

  attr :visible, :boolean, default: false
  attr :bots, :list, default: []
  attr :selected, :any, default: nil
  attr :channels, :list, default: []
  attr :commands, :list, default: []
  attr :active_tab, :atom, default: :general
  attr :is_admin, :boolean, default: false

  @spec bot_management_dialog(map()) :: Phoenix.LiveView.Rendered.t()
  def bot_management_dialog(assigns) do
    ~H"""
    <div
      :if={@visible}
      class="dialog-overlay"
      id="bot-management-dialog"
      data-testid="bot-management-dialog"
    >
      <div class="window bot-mgmt-dialog">
        <div class="title-bar">
          <div class="title-bar-text">
            <span>&#9881;</span> Bot Management
          </div>
          <div class="title-bar-controls">
            <button type="button" aria-label="Close" phx-click="close_bot_dialog"></button>
          </div>
        </div>
        <div class="window-body bot-mgmt-body">
          <div class="bot-mgmt-split">
            <%!-- Left panel: bot list --%>
            <div class="bot-mgmt-sidebar">
              <div class="bot-mgmt-sidebar-header">Bots</div>
              <ul class="bot-mgmt-list" data-testid="bot-list">
                <li
                  :for={bot <- @bots}
                  class={"bot-mgmt-list-item #{if @selected && @selected.id == bot.id, do: "bot-mgmt-list-item--selected"}"}
                  phx-click="bot_select"
                  phx-value-name={bot.name}
                  data-testid={"bot-item-#{bot.name}"}
                >
                  <span
                    class="bot-mgmt-status"
                    title={if bot.enabled, do: "Enabled", else: "Disabled"}
                  >
                    {if bot.enabled, do: raw("&#9679;"), else: raw("&#9675;")}
                  </span>
                  <span class="bot-mgmt-name">{bot.name}</span>
                </li>
              </ul>
              <div :if={@is_admin} class="bot-mgmt-sidebar-actions">
                <button
                  type="button"
                  class="bot-mgmt-btn"
                  phx-click="open_new_bot_dialog"
                  data-testid="new-bot-btn"
                >
                  New Bot...
                </button>
              </div>
            </div>

            <%!-- Right panel: details --%>
            <div class="bot-mgmt-detail">
              <div :if={@selected == nil} class="bot-mgmt-empty">
                <p>Select a bot to view details.</p>
              </div>

              <div :if={@selected != nil}>
                <div class="bot-mgmt-detail-header">
                  {raw("&#9881;")} {@selected.name}
                </div>

                <%!-- Tab bar --%>
                <div class="bot-mgmt-tabs">
                  <button
                    :for={tab <- [:general, :capabilities, :channels, :commands, :events]}
                    type="button"
                    class={"bot-mgmt-tab #{if @active_tab == tab, do: "bot-mgmt-tab--active"}"}
                    phx-click="bot_dialog_tab"
                    phx-value-tab={tab}
                    data-testid={"bot-tab-#{tab}"}
                  >
                    {tab_label(tab)}
                  </button>
                </div>

                <%!-- Tab content --%>
                <div class="bot-mgmt-tab-content">
                  <.general_tab :if={@active_tab == :general} bot={@selected} is_admin={@is_admin} />
                  <.capabilities_tab
                    :if={@active_tab == :capabilities}
                    bot={@selected}
                    is_admin={@is_admin}
                  />
                  <.channels_tab
                    :if={@active_tab == :channels}
                    bot={@selected}
                    channels={@channels}
                    is_admin={@is_admin}
                  />
                  <.commands_tab
                    :if={@active_tab == :commands}
                    bot={@selected}
                    commands={@commands}
                    is_admin={@is_admin}
                  />
                  <.events_tab :if={@active_tab == :events} bot={@selected} is_admin={@is_admin} />
                </div>
              </div>
            </div>
          </div>

          <%!-- Bottom buttons --%>
          <div class="bot-mgmt-footer">
            <div :if={@is_admin && @selected} class="bot-mgmt-footer-left">
              <button
                type="button"
                class="bot-mgmt-btn"
                phx-click="bot_toggle_enabled"
                phx-value-name={@selected.name}
                data-testid="bot-toggle-btn"
              >
                {if @selected.enabled, do: "Disable", else: "Enable"}
              </button>
              <button
                type="button"
                class="bot-mgmt-btn bot-mgmt-btn--danger"
                phx-click="bot_delete"
                phx-value-name={@selected.name}
                data-testid="bot-delete-btn"
              >
                Delete
              </button>
            </div>
            <div class="bot-mgmt-footer-right">
              <button type="button" class="bot-mgmt-btn" phx-click="close_bot_dialog">
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ── Tab components ──

  attr :bot, :any, required: true
  attr :is_admin, :boolean, default: false

  defp general_tab(assigns) do
    ~H"""
    <fieldset class="bot-mgmt-fieldset">
      <legend>Identity</legend>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Name:</span>
        <span class="bot-mgmt-value">{@bot.name}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Nickname:</span>
        <span class="bot-mgmt-value">{@bot.nickname}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Description:</span>
        <span class="bot-mgmt-value">{@bot.description || "—"}</span>
      </div>
    </fieldset>

    <fieldset class="bot-mgmt-fieldset">
      <legend>Behavior</legend>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Prefix:</span>
        <span class="bot-mgmt-value">{@bot.command_prefix}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Cooldown:</span>
        <span class="bot-mgmt-value">{@bot.cooldown_ms}ms</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Status:</span>
        <span class={"bot-mgmt-value #{if @bot.enabled, do: "bot-mgmt-status--on", else: "bot-mgmt-status--off"}"}>
          {if @bot.enabled, do: "Enabled", else: "Disabled"}
        </span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Created by:</span>
        <span class="bot-mgmt-value">{@bot.created_by}</span>
      </div>
    </fieldset>

    <fieldset class="bot-mgmt-fieldset">
      <legend>Capabilities</legend>
      <div class="bot-mgmt-caps">
        <.cap_badge :for={{name, config} <- @bot.capabilities || %{}} name={name} config={config} />
      </div>
    </fieldset>
    """
  end

  attr :bot, :any, required: true
  attr :channels, :list, default: []
  attr :is_admin, :boolean, default: false

  defp channels_tab(assigns) do
    ~H"""
    <div class="bot-mgmt-channels">
      <table class="bot-mgmt-table">
        <thead>
          <tr>
            <th>Channel</th>
            <th>Enabled</th>
            <th :if={@is_admin}></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={ch <- @channels} data-testid={"bot-channel-#{ch.channel_name}"}>
            <td>{ch.channel_name}</td>
            <td>{if ch.enabled, do: "Yes", else: "No"}</td>
            <td :if={@is_admin}>
              <button
                type="button"
                class="bot-mgmt-btn-sm"
                phx-click="bot_remove_channel"
                phx-value-channel={ch.channel_name}
                phx-value-bot_name={@bot.name}
              >
                Remove
              </button>
            </td>
          </tr>
          <tr :if={@channels == []}>
            <td colspan={if @is_admin, do: "3", else: "2"} class="bot-mgmt-empty-cell">
              No channels configured
            </td>
          </tr>
        </tbody>
      </table>

      <div :if={@is_admin} class="bot-mgmt-channel-add">
        <form phx-submit="bot_add_channel" class="bot-mgmt-inline-form">
          <input type="hidden" name="bot_name" value={@bot.name} />
          <input
            type="text"
            name="channel"
            placeholder="#channel"
            class="bot-mgmt-input"
            data-testid="bot-add-channel-input"
          />
          <button type="submit" class="bot-mgmt-btn" data-testid="bot-add-channel-btn">Add</button>
        </form>
      </div>
    </div>
    """
  end

  attr :bot, :any, required: true
  attr :commands, :list, default: []
  attr :is_admin, :boolean, default: false

  defp commands_tab(assigns) do
    ~H"""
    <div class="bot-mgmt-commands">
      <table class="bot-mgmt-table">
        <thead>
          <tr>
            <th>Trigger</th>
            <th>Response</th>
            <th :if={@is_admin}></th>
          </tr>
        </thead>
        <tbody>
          <tr :for={cmd <- @commands} data-testid={"bot-cmd-#{cmd.trigger}"}>
            <td><code>{@bot.command_prefix}{@bot.name} {cmd.trigger}</code></td>
            <td class="bot-mgmt-cmd-response">{cmd.response}</td>
            <td :if={@is_admin}>
              <button
                type="button"
                class="bot-mgmt-btn-sm"
                phx-click="bot_remove_command"
                phx-value-trigger={cmd.trigger}
                phx-value-bot_name={@bot.name}
              >
                Remove
              </button>
            </td>
          </tr>
          <tr :if={@commands == []}>
            <td colspan={if @is_admin, do: "3", else: "2"} class="bot-mgmt-empty-cell">
              No custom commands
            </td>
          </tr>
        </tbody>
      </table>

      <div :if={@is_admin} class="bot-mgmt-cmd-actions">
        <button
          type="button"
          class="bot-mgmt-btn"
          phx-click="open_add_command_dialog"
          data-testid="add-command-btn"
        >
          Add Command...
        </button>
      </div>
    </div>
    """
  end

  attr :bot, :any, required: true
  attr :is_admin, :boolean, default: false

  defp events_tab(assigns) do
    greeter = Map.get(assigns.bot.capabilities || %{}, "greeter", %{})
    mention = Map.get(assigns.bot.capabilities || %{}, "mention", %{})

    assigns =
      assigns
      |> assign(:greeting, Map.get(greeter, "greeting", "Welcome, {nickname}!"))
      |> assign(:farewell, Map.get(greeter, "farewell"))
      |> assign(
        :mention_response,
        Map.get(mention, "response", "Hi {nickname}! Try {prefix}help for my commands.")
      )

    ~H"""
    <fieldset class="bot-mgmt-fieldset">
      <legend>Event Hooks</legend>

      <div class="bot-mgmt-event-row">
        <span class="bot-mgmt-event-label">Greet on join:</span>
        <span class="bot-mgmt-event-value">{@greeting}</span>
      </div>

      <div class="bot-mgmt-event-row">
        <span class="bot-mgmt-event-label">Farewell on part:</span>
        <span class="bot-mgmt-event-value">{@farewell || "(disabled)"}</span>
      </div>

      <div class="bot-mgmt-event-row">
        <span class="bot-mgmt-event-label">Mention response:</span>
        <span class="bot-mgmt-event-value">{@mention_response}</span>
      </div>

      <div class="bot-mgmt-placeholders">
        <em>Placeholders: {"{nickname}"}, {"{channel}"}, {"{topic}"}, {"{prefix}"}, {"{botname}"}</em>
      </div>
    </fieldset>
    """
  end

  # ── Capabilities Tab ──

  attr :bot, :any, required: true
  attr :is_admin, :boolean, default: false

  defp capabilities_tab(assigns) do
    caps = assigns.bot.capabilities || %{}
    assigns = assign(assigns, :caps, caps)

    ~H"""
    <div class="bot-mgmt-caps-config">
      <.dice_config :if={Map.has_key?(@caps, "dice")} config={@caps["dice"]} is_admin={@is_admin} />
      <.moderation_config
        :if={Map.has_key?(@caps, "moderation")}
        config={@caps["moderation"]}
        is_admin={@is_admin}
      />
      <.trivia_config
        :if={Map.has_key?(@caps, "trivia")}
        config={@caps["trivia"]}
        is_admin={@is_admin}
      />
      <.scheduler_config
        :if={Map.has_key?(@caps, "scheduler")}
        config={@caps["scheduler"]}
        is_admin={@is_admin}
      />
      <.rss_config :if={Map.has_key?(@caps, "rss")} config={@caps["rss"]} is_admin={@is_admin} />

      <div
        :if={
          !Map.has_key?(@caps, "dice") && !Map.has_key?(@caps, "moderation") &&
            !Map.has_key?(@caps, "trivia") && !Map.has_key?(@caps, "scheduler") &&
            !Map.has_key?(@caps, "rss")
        }
        class="bot-mgmt-caps-empty"
      >
        No configurable capabilities enabled.
      </div>
    </div>
    """
  end

  attr :config, :map, required: true
  attr :is_admin, :boolean, default: false

  defp dice_config(assigns) do
    config = assigns.config
    enabled = Map.get(config, "enabled", true)
    max_dice = Map.get(config, "max_dice", 100)
    max_sides = Map.get(config, "max_sides", 1000)
    default_notation = Map.get(config, "default_notation", "d20")

    assigns =
      assign(assigns,
        enabled: enabled,
        max_dice: max_dice,
        max_sides: max_sides,
        default_notation: default_notation
      )

    ~H"""
    <fieldset class="bot-mgmt-fieldset">
      <legend>&#127922; Dice</legend>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Status:</span>
        <span class={cap_status_class(@enabled)}>
          {if @enabled, do: "Enabled", else: "Disabled"}
        </span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Max Dice:</span>
        <span class="bot-mgmt-value">{@max_dice}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Max Sides:</span>
        <span class="bot-mgmt-value">{@max_sides}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Default:</span>
        <span class="bot-mgmt-value">{@default_notation}</span>
      </div>
      <div :if={@is_admin} class="bot-mgmt-cap-hint">
        /bot set &lt;name&gt; dice_max_dice, dice_max_sides, dice_default
      </div>
    </fieldset>
    """
  end

  attr :config, :map, required: true
  attr :is_admin, :boolean, default: false

  defp moderation_config(assigns) do
    config = assigns.config
    enabled = Map.get(config, "enabled", true)
    words = Map.get(config, "blocked_words", [])
    action = Map.get(config, "action", "warn")
    spam = Map.get(config, "spam_threshold", 3)
    flood = Map.get(config, "flood_threshold", 5)

    assigns =
      assign(assigns,
        enabled: enabled,
        word_count: length(words),
        action: action,
        spam: spam,
        flood: flood
      )

    ~H"""
    <fieldset class="bot-mgmt-fieldset">
      <legend>&#128737; Moderation</legend>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Status:</span>
        <span class={cap_status_class(@enabled)}>
          {if @enabled, do: "Enabled", else: "Disabled"}
        </span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Action:</span>
        <span class="bot-mgmt-value">{@action}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Blocked:</span>
        <span class="bot-mgmt-value">{@word_count} word(s)</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Spam:</span>
        <span class="bot-mgmt-value">{@spam} msgs threshold</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Flood:</span>
        <span class="bot-mgmt-value">{@flood} msgs threshold</span>
      </div>
      <div :if={@is_admin} class="bot-mgmt-cap-hint">
        /bot set &lt;name&gt; mod_words, mod_action, mod_spam, mod_flood
      </div>
    </fieldset>
    """
  end

  attr :config, :map, required: true
  attr :is_admin, :boolean, default: false

  defp trivia_config(assigns) do
    config = assigns.config
    enabled = Map.get(config, "enabled", true)
    category = Map.get(config, "category", "general")
    questions = Map.get(config, "questions_per_round", 10)
    time_limit = Map.get(config, "time_limit_sec", 30)
    points = Map.get(config, "points_per_answer", 10)

    assigns =
      assign(assigns,
        enabled: enabled,
        category: category,
        questions: questions,
        time_limit: time_limit,
        points: points
      )

    ~H"""
    <fieldset class="bot-mgmt-fieldset">
      <legend>&#10068; Trivia</legend>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Status:</span>
        <span class={cap_status_class(@enabled)}>
          {if @enabled, do: "Enabled", else: "Disabled"}
        </span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Category:</span>
        <span class="bot-mgmt-value">{@category}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Questions:</span>
        <span class="bot-mgmt-value">{@questions} per round</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Time Limit:</span>
        <span class="bot-mgmt-value">{@time_limit}s</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Points:</span>
        <span class="bot-mgmt-value">{@points} per answer</span>
      </div>
      <div :if={@is_admin} class="bot-mgmt-cap-hint">
        /bot set &lt;name&gt; trivia_category, trivia_time, trivia_questions, trivia_points
      </div>
    </fieldset>
    """
  end

  attr :config, :map, required: true
  attr :is_admin, :boolean, default: false

  defp scheduler_config(assigns) do
    config = assigns.config
    enabled = Map.get(config, "enabled", true)
    max_sched = Map.get(config, "max_schedules", 10)
    min_interval = Map.get(config, "min_interval_min", 5)
    schedules = Map.get(config, "schedules", [])

    assigns =
      assign(assigns,
        enabled: enabled,
        max_sched: max_sched,
        min_interval: min_interval,
        schedule_count: length(schedules),
        schedules: Enum.take(schedules, 5)
      )

    ~H"""
    <fieldset class="bot-mgmt-fieldset">
      <legend>&#128339; Scheduler</legend>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Status:</span>
        <span class={cap_status_class(@enabled)}>
          {if @enabled, do: "Enabled", else: "Disabled"}
        </span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Max:</span>
        <span class="bot-mgmt-value">{@max_sched} schedules</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Min interval:</span>
        <span class="bot-mgmt-value">{@min_interval} min</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Active:</span>
        <span class="bot-mgmt-value">{@schedule_count} schedule(s)</span>
      </div>
      <table :if={@schedules != []} class="bot-mgmt-table bot-mgmt-cap-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Type</th>
            <th>Channel</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={s <- @schedules}>
            <td>{s["id"]}</td>
            <td>{format_sched_type(s)}</td>
            <td>{s["channel"]}</td>
          </tr>
        </tbody>
      </table>
      <div :if={@is_admin} class="bot-mgmt-cap-hint">
        /bot set &lt;name&gt; sched_max, sched_min_interval
      </div>
    </fieldset>
    """
  end

  attr :config, :map, required: true
  attr :is_admin, :boolean, default: false

  defp rss_config(assigns) do
    config = assigns.config
    enabled = Map.get(config, "enabled", true)
    interval = Map.get(config, "poll_interval_min", 30)
    max_feeds = Map.get(config, "max_feeds", 5)
    max_items = Map.get(config, "max_items_per_poll", 3)
    feeds = Map.get(config, "feeds", [])

    assigns =
      assign(assigns,
        enabled: enabled,
        interval: interval,
        max_feeds: max_feeds,
        max_items: max_items,
        feed_count: length(feeds),
        feeds: Enum.take(feeds, 5)
      )

    ~H"""
    <fieldset class="bot-mgmt-fieldset">
      <legend>&#128246; RSS</legend>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Status:</span>
        <span class={cap_status_class(@enabled)}>
          {if @enabled, do: "Enabled", else: "Disabled"}
        </span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Poll:</span>
        <span class="bot-mgmt-value">every {@interval} min</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Max feeds:</span>
        <span class="bot-mgmt-value">{@max_feeds}</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Max items:</span>
        <span class="bot-mgmt-value">{@max_items} per poll</span>
      </div>
      <div class="bot-mgmt-field">
        <span class="bot-mgmt-label">Active:</span>
        <span class="bot-mgmt-value">{@feed_count} feed(s)</span>
      </div>
      <table :if={@feeds != []} class="bot-mgmt-table bot-mgmt-cap-table">
        <thead>
          <tr>
            <th>ID</th>
            <th>Title</th>
            <th>Channel</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={f <- @feeds}>
            <td>{f["id"]}</td>
            <td>{f["title"] || "(untitled)"}</td>
            <td>{f["channel"]}</td>
          </tr>
        </tbody>
      </table>
      <div :if={@is_admin} class="bot-mgmt-cap-hint">
        /bot set &lt;name&gt; rss_interval, rss_max_feeds, rss_max_items
      </div>
    </fieldset>
    """
  end

  # ── Helpers ──

  @spec cap_status_class(boolean()) :: String.t()
  defp cap_status_class(true), do: "bot-mgmt-value bot-mgmt-status--on"
  defp cap_status_class(false), do: "bot-mgmt-value bot-mgmt-status--off"

  @spec format_sched_type(map()) :: String.t()
  defp format_sched_type(%{"type" => "interval", "interval_min" => min}), do: "q/#{min}min"
  defp format_sched_type(%{"type" => "daily", "time" => time}), do: "daily@#{time}"
  defp format_sched_type(_), do: "unknown"

  attr :name, :string, required: true
  attr :config, :map, required: true

  defp cap_badge(assigns) do
    enabled = Map.get(assigns.config, "enabled", true)
    assigns = assign(assigns, :enabled, enabled)

    ~H"""
    <span class={"bot-mgmt-cap #{if @enabled, do: "bot-mgmt-cap--on", else: "bot-mgmt-cap--off"}"}>
      {cap_display_name(@name)}
    </span>
    """
  end

  @spec tab_label(atom()) :: String.t()
  defp tab_label(:general), do: "General"
  defp tab_label(:capabilities), do: "Capabilities"
  defp tab_label(:channels), do: "Channels"
  defp tab_label(:commands), do: "Commands"
  defp tab_label(:events), do: "Events"

  @spec cap_display_name(String.t()) :: String.t()
  defp cap_display_name("mention"), do: "Mentions"
  defp cap_display_name("greeter"), do: "Greeter"
  defp cap_display_name("custom_commands"), do: "Commands"
  defp cap_display_name("help"), do: "Help"
  defp cap_display_name("llm"), do: "LLM"
  defp cap_display_name("script"), do: "Script"
  defp cap_display_name("game"), do: "Game"
  defp cap_display_name("scheduler"), do: "Scheduler"
  defp cap_display_name("moderation"), do: "Moderation"
  defp cap_display_name("rss"), do: "RSS"
  defp cap_display_name("trivia"), do: "Trivia"
  defp cap_display_name("dice"), do: "Dice"
  defp cap_display_name(other), do: other
end

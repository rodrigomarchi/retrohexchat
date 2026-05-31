defmodule RetroHexChat.Commands.Handlers.Bot do
  @moduledoc "Handler for /bot (Bot management commands)"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Bots.Capabilities.{CustomCommands, Greeter, Help, Mention}
  alias RetroHexChat.Bots.{Lifecycle, Policy, Queries, Server, Supervisor}
  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], context) do
    if Policy.can_manage?(context) do
      {:ok, :ui_action, :open_bot_dialog, %{}}
    else
      {:ok, :system, %{content: format_bot_list()}}
    end
  end

  def execute(["create", name | rest], context) do
    with :ok <- Policy.authorize(context) do
      description = if rest == [], do: nil, else: Enum.join(rest, " ")
      do_create(name, description, context.nickname)
    end
  end

  def execute(["destroy", name], context) do
    with :ok <- Policy.authorize(context) do
      do_destroy(name)
    end
  end

  def execute(["list"], _context) do
    {:ok, :system, %{content: format_bot_list()}}
  end

  def execute(["info", name], _context) do
    do_info(name)
  end

  def execute(["join", bot_name, channel], context) do
    with :ok <- Policy.authorize(context) do
      do_join(bot_name, channel)
    end
  end

  def execute(["part", bot_name, channel], context) do
    with :ok <- Policy.authorize(context) do
      do_part(bot_name, channel)
    end
  end

  def execute(["enable", bot_name], context) do
    with :ok <- Policy.authorize(context) do
      do_set_enabled(bot_name, true)
    end
  end

  def execute(["disable", bot_name], context) do
    with :ok <- Policy.authorize(context) do
      do_set_enabled(bot_name, false)
    end
  end

  def execute(["set", bot_name, key | value_parts], context) do
    with :ok <- Policy.authorize(context) do
      value = Enum.join(value_parts, " ")
      do_set(bot_name, key, value)
    end
  end

  def execute(["commands", bot_name], _context) do
    do_list_commands(bot_name)
  end

  def execute(["addcmd", bot_name, trigger | response_parts], context) do
    with :ok <- Policy.authorize(context) do
      response = Enum.join(response_parts, " ")
      do_add_command(bot_name, trigger, response, context.nickname)
    end
  end

  def execute(["delcmd", bot_name, trigger], context) do
    with :ok <- Policy.authorize(context) do
      do_delete_command(bot_name, trigger)
    end
  end

  def execute(["help"], _context) do
    {:ok, :system, %{content: help_text()}}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown /bot subcommand: #{subcmd}. Try /bot help"}
  end

  @impl true
  @spec help() :: map()
  def help do
    %{
      name: "bot",
      syntax: dgettext("commands", "/bot <subcommand> [args]"),
      description:
        dgettext("commands", "Create, manage, and configure bots for your channels.\n") <>
          dgettext(
            "commands",
            "Subcommands: create, destroy, list, info, join, part, enable, disable, "
          ) <>
          dgettext("commands", "set, commands, addcmd, delcmd, help.\n") <>
          dgettext(
            "commands",
            "Without arguments, opens the Bot Management dialog (admins) or shows bot list."
          ),
      examples: [
        dgettext("commands", "/bot create GreeterBot Welcomes new users"),
        dgettext("commands", "/bot join GreeterBot #general"),
        dgettext("commands", "/bot addcmd GreeterBot rules Read the #rules channel"),
        dgettext("commands", "/bot set GreeterBot greeting Welcome, {nickname}!"),
        dgettext("commands", "/bot info GreeterBot"),
        dgettext("commands", "/bot list"),
        dgettext("commands", "/bot disable GreeterBot")
      ]
    }
  end

  @impl true
  @spec category() :: Handler.category()
  def category, do: :advanced

  # ── Private helpers ──

  @spec do_create(String.t(), String.t() | nil, String.t()) :: Handler.result()
  defp do_create(name, description, creator) do
    default_caps = %{
      "mention" => Mention.default_config(),
      "greeter" => Greeter.default_config(),
      "custom_commands" => CustomCommands.default_config(),
      "help" => Help.default_config()
    }

    attrs = %{
      name: name,
      nickname: name,
      description: description,
      created_by: creator,
      capabilities: default_caps
    }

    case Queries.create_bot(attrs) do
      {:ok, bot} ->
        bot_data = %{
          id: bot.id,
          name: bot.name,
          nickname: bot.nickname,
          command_prefix: bot.command_prefix,
          created_by: bot.created_by,
          enabled: bot.enabled,
          cooldown_ms: bot.cooldown_ms,
          capabilities: bot.capabilities,
          channel_configs: [],
          custom_commands: []
        }

        Supervisor.start_bot(bot_data)

        {:ok, :system,
         %{
           content:
             dgettext("commands", "[BotService] Bot '%{name}' created successfully.", name: name)
         }}

      {:error, changeset} ->
        msg = format_changeset_errors(changeset)

        {:error,
         dgettext("commands", "[BotService] Failed to create bot: %{message}", message: msg)}
    end
  end

  @spec do_destroy(String.t()) :: Handler.result()
  defp do_destroy(name) do
    case Queries.get_bot_by_name(name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: name)}

      bot ->
        Lifecycle.destroy_bot(bot)

        {:ok, :system,
         %{content: dgettext("commands", "[BotService] Bot '%{name}' destroyed.", name: name)}}
    end
  end

  @spec do_info(String.t()) :: Handler.result()
  defp do_info(name) do
    case Queries.get_bot_by_name(name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: name)}

      bot ->
        channels = Queries.list_channel_configs(bot.id)
        commands = Queries.list_custom_commands(bot.id)

        status =
          if bot.enabled,
            do: dgettext("commands", "Enabled"),
            else: dgettext("commands", "Disabled")

        runtime_info =
          case Server.get_state(bot.nickname) do
            {:ok, state} ->
              dgettext("commands", "Uptime stats: %{state_stats_messages_handled} msgs handled",
                state_stats_messages_handled: state.stats.messages_handled
              )

            {:error, :not_found} ->
              dgettext("commands", "Process: Not running")
          end

        lines =
          [
            dgettext("commands", "[BotService] Bot Info: %{name}", name: bot.name),
            dgettext("commands", "  Nickname: %{nickname}", nickname: bot.nickname),
            dgettext("commands", "  Status: %{status}", status: status),
            dgettext("commands", "  Prefix: %{command_prefix}",
              command_prefix: bot.command_prefix
            ),
            dgettext("commands", "  Cooldown: %{cooldown_ms}ms", cooldown_ms: bot.cooldown_ms),
            dgettext("commands", "  Created by: %{created_by}", created_by: bot.created_by),
            dgettext("commands", "  Channels: %{channels_count}",
              channels_count: length(channels)
            ),
            dgettext("commands", "  Commands: %{commands_count}",
              commands_count: length(commands)
            ),
            "  #{runtime_info}"
          ]
          |> maybe_add_description(bot.description)

        {:ok, :system, %{content: Enum.join(lines, "\n")}}
    end
  end

  @spec do_join(String.t(), String.t()) :: Handler.result()
  defp do_join(bot_name, channel) do
    channel = ensure_hash(channel)

    case Queries.get_bot_by_name(bot_name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: bot_name)}

      bot ->
        join_bot_to_channel(bot, bot_name, channel)
    end
  end

  defp join_bot_to_channel(bot, bot_name, channel) do
    case Queries.add_channel_config(bot.id, channel) do
      {:ok, _} ->
        notify_bot_if_running(bot.nickname, &Server.join_channel(&1, channel))

        {:ok, :system,
         %{
           content:
             dgettext("commands", "[BotService] Bot '%{name}' joined %{channel}.",
               name: bot_name,
               channel: channel
             )
         }}

      {:error, _} ->
        {:error,
         dgettext("commands", "[BotService] Bot '%{name}' is already in %{channel}.",
           name: bot_name,
           channel: channel
         )}
    end
  end

  @spec do_part(String.t(), String.t()) :: Handler.result()
  defp do_part(bot_name, channel) do
    channel = ensure_hash(channel)

    case Queries.get_bot_by_name(bot_name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: bot_name)}

      bot ->
        Queries.remove_channel_config(bot.id, channel)
        notify_bot_if_running(bot.nickname, &Server.part_channel(&1, channel))

        {:ok, :system,
         %{
           content:
             dgettext("commands", "[BotService] Bot '%{name}' left %{channel}.",
               name: bot_name,
               channel: channel
             )
         }}
    end
  end

  @spec do_set_enabled(String.t(), boolean()) :: Handler.result()
  defp do_set_enabled(bot_name, enabled) do
    case Queries.get_bot_by_name(bot_name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: bot_name)}

      bot ->
        Queries.update_bot(bot, %{enabled: enabled})
        notify_bot_if_running(bot.nickname, &Server.set_enabled(&1, enabled))

        action = if enabled, do: "enabled", else: "disabled"

        {:ok, :system,
         %{
           content:
             dgettext("commands", "[BotService] Bot '%{name}' %{action}.",
               name: bot_name,
               action: action
             )
         }}
    end
  end

  @spec do_set(String.t(), String.t(), String.t()) :: Handler.result()
  defp do_set(bot_name, key, value) do
    case Queries.get_bot_by_name(bot_name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: bot_name)}

      bot ->
        case apply_setting(bot, key, value) do
          {:ok, msg} ->
            {:ok, :system,
             %{content: dgettext("commands", "[BotService] %{message}", message: msg)}}

          {:error, msg} ->
            {:error, dgettext("commands", "[BotService] %{message}", message: msg)}
        end
    end
  end

  @spec apply_setting(map(), String.t(), String.t()) :: {:ok, String.t()} | {:error, String.t()}
  defp apply_setting(bot, "prefix", value) do
    case Queries.update_bot(bot, %{command_prefix: value}) do
      {:ok, _} ->
        maybe_update_running(bot.nickname, %{command_prefix: value})
        {:ok, dgettext("commands", "Prefix set to '%{value}'.", value: value)}

      {:error, _} ->
        {:error, dgettext("commands", "Invalid prefix.")}
    end
  end

  defp apply_setting(bot, "cooldown", value) do
    case Integer.parse(value) do
      {ms, _} ->
        case Queries.update_bot(bot, %{cooldown_ms: ms}) do
          {:ok, _} ->
            maybe_update_running(bot.nickname, %{cooldown_ms: ms})
            {:ok, dgettext("commands", "Cooldown set to %{ms}ms.", ms: ms)}

          {:error, _} ->
            {:error, dgettext("commands", "Invalid cooldown value.")}
        end

      :error ->
        {:error, dgettext("commands", "Cooldown must be a number.")}
    end
  end

  defp apply_setting(bot, "description", value) do
    Queries.update_bot(bot, %{description: value})
    {:ok, dgettext("commands", "Description updated.")}
  end

  defp apply_setting(bot, "greeting", value) do
    greeting = if value == "none", do: nil, else: value
    caps = Map.update(bot.capabilities, "greeter", %{}, &Map.put(&1, "greeting", greeting))
    Queries.update_bot(bot, %{capabilities: caps})
    reload_bot_capabilities(bot)

    message =
      if greeting do
        dgettext("commands", "Greeting set to '%{greeting}'.", greeting: greeting)
      else
        dgettext("commands", "Greeting disabled.")
      end

    {:ok, message}
  end

  defp apply_setting(bot, "farewell", value) do
    farewell = if value == "none", do: nil, else: value
    caps = Map.update(bot.capabilities, "greeter", %{}, &Map.put(&1, "farewell", farewell))
    Queries.update_bot(bot, %{capabilities: caps})
    reload_bot_capabilities(bot)

    message =
      if farewell do
        dgettext("commands", "Farewell set to '%{farewell}'.", farewell: farewell)
      else
        dgettext("commands", "Farewell disabled.")
      end

    {:ok, message}
  end

  defp apply_setting(bot, "mention_response", value) do
    caps = Map.update(bot.capabilities, "mention", %{}, &Map.put(&1, "response", value))
    Queries.update_bot(bot, %{capabilities: caps})
    reload_bot_capabilities(bot)
    {:ok, dgettext("commands", "Mention response updated.")}
  end

  # ── Dice settings ──

  defp apply_setting(bot, "dice_max_dice", value) do
    update_capability_int(bot, "dice", "max_dice", value, 1, 1000)
  end

  defp apply_setting(bot, "dice_max_sides", value) do
    update_capability_int(bot, "dice", "max_sides", value, 2, 10_000)
  end

  defp apply_setting(bot, "dice_default", value) do
    update_capability_field(bot, "dice", "default_notation", value)
  end

  # ── Moderation settings ──

  defp apply_setting(bot, "mod_words", value) do
    words = value |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    update_capability_field(bot, "moderation", "blocked_words", words)
  end

  defp apply_setting(bot, "mod_action", value) do
    if value in ["warn", "mute", "kick"] do
      update_capability_field(bot, "moderation", "action", value)
    else
      {:error, dgettext("commands", "Action must be: warn, mute, or kick.")}
    end
  end

  defp apply_setting(bot, "mod_spam", value) do
    update_capability_int(bot, "moderation", "spam_threshold", value, 2, 100)
  end

  defp apply_setting(bot, "mod_flood", value) do
    update_capability_int(bot, "moderation", "flood_threshold", value, 2, 100)
  end

  defp apply_setting(bot, "mod_warn", value) do
    update_capability_field(bot, "moderation", "warn_message", value)
  end

  # ── Trivia settings ──

  defp apply_setting(bot, "trivia_category", value) do
    update_capability_field(bot, "trivia", "category", value)
  end

  defp apply_setting(bot, "trivia_time", value) do
    update_capability_int(bot, "trivia", "time_limit_sec", value, 5, 300)
  end

  defp apply_setting(bot, "trivia_questions", value) do
    update_capability_int(bot, "trivia", "questions_per_round", value, 1, 50)
  end

  defp apply_setting(bot, "trivia_points", value) do
    update_capability_int(bot, "trivia", "points_per_answer", value, 1, 1000)
  end

  # ── Scheduler settings ──

  defp apply_setting(bot, "sched_max", value) do
    update_capability_int(bot, "scheduler", "max_schedules", value, 1, 50)
  end

  defp apply_setting(bot, "sched_min_interval", value) do
    update_capability_int(bot, "scheduler", "min_interval_min", value, 1, 1440)
  end

  # ── RSS settings ──

  defp apply_setting(bot, "rss_interval", value) do
    update_capability_int(bot, "rss", "poll_interval_min", value, 5, 1440)
  end

  defp apply_setting(bot, "rss_max_feeds", value) do
    update_capability_int(bot, "rss", "max_feeds", value, 1, 20)
  end

  defp apply_setting(bot, "rss_max_items", value) do
    update_capability_int(bot, "rss", "max_items_per_poll", value, 1, 10)
  end

  # ── Arcade settings ──

  defp apply_setting(bot, "arcade_enabled", value) do
    case String.downcase(value) do
      v when v in ["true", "1", "yes", "on"] ->
        update_capability_field(bot, "arcade", "enabled", true)

      v when v in ["false", "0", "no", "off"] ->
        caps = Map.delete(bot.capabilities, "arcade")
        Queries.update_bot(bot, %{capabilities: caps})
        reload_bot_capabilities(bot)
        {:ok, dgettext("commands", "Arcade capability disabled.")}

      _ ->
        {:error, dgettext("commands", "arcade_enabled must be: true or false.")}
    end
  end

  defp apply_setting(_bot, key, _value) do
    {:error,
     dgettext(
       "commands",
       "Unknown setting '%{key}'. Valid: prefix, cooldown, description, greeting, farewell, ",
       key: key
     ) <>
       dgettext("commands", "mention_response, dice_*, mod_*, trivia_*, sched_*, rss_*, arcade_*")}
  end

  @spec update_capability_field(map(), String.t(), String.t(), term()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp update_capability_field(bot, cap_name, field, value) do
    caps = Map.update(bot.capabilities, cap_name, %{}, &Map.put(&1, field, value))
    Queries.update_bot(bot, %{capabilities: caps})
    reload_bot_capabilities(bot)
    display = if is_list(value), do: Enum.join(value, ", "), else: inspect(value)

    {:ok,
     dgettext("commands", "%{cap_name}.%{field} set to %{display}.",
       cap_name: cap_name,
       field: field,
       display: display
     )}
  end

  @spec update_capability_int(map(), String.t(), String.t(), String.t(), integer(), integer()) ::
          {:ok, String.t()} | {:error, String.t()}
  defp update_capability_int(bot, cap_name, field, value_str, min, max) do
    case Integer.parse(value_str) do
      {n, _} when n >= min and n <= max ->
        update_capability_field(bot, cap_name, field, n)

      {_, _} ->
        {:error, "#{field} must be between #{min} and #{max}."}

      :error ->
        {:error, "#{field} must be a number."}
    end
  end

  @spec do_list_commands(String.t()) :: Handler.result()
  defp do_list_commands(bot_name) do
    case Queries.get_bot_by_name(bot_name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: bot_name)}

      bot ->
        commands = Queries.list_custom_commands(bot.id)
        format_command_list(bot, bot_name, commands)
    end
  end

  defp format_command_list(_bot, bot_name, []) do
    {:ok, :system,
     %{
       content:
         dgettext("commands", "[BotService] %{name} has no custom commands.", name: bot_name)
     }}
  end

  defp format_command_list(bot, bot_name, commands) do
    lines =
      [dgettext("commands", "[BotService] Commands for %{bot_name}:", bot_name: bot_name)] ++
        Enum.map(commands, &format_command_line(bot, bot_name, &1))

    {:ok, :system, %{content: Enum.join(lines, "\n")}}
  end

  defp format_command_line(bot, bot_name, cmd) do
    status = if cmd.enabled, do: "", else: " [disabled]"

    dgettext(
      "commands",
      "  %{command_prefix}%{bot_name} %{trigger} — %{cmd_description_cmd_response}%{status}",
      command_prefix: bot.command_prefix,
      bot_name: bot_name,
      trigger: cmd.trigger,
      cmd_description_cmd_response: cmd.description || cmd.response,
      status: status
    )
  end

  @spec do_add_command(String.t(), String.t(), String.t(), String.t()) :: Handler.result()
  defp do_add_command(bot_name, trigger, response, added_by) do
    case Queries.get_bot_by_name(bot_name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: bot_name)}

      bot ->
        attrs = %{trigger: trigger, response: response, added_by: added_by}

        case Queries.add_custom_command(bot.id, attrs) do
          {:ok, _} ->
            reload_bot_commands(bot)

            {:ok, :system,
             %{
               content:
                 dgettext("commands", "[BotService] Command '%{trigger}' set for %{name}.",
                   trigger: trigger,
                   name: bot_name
                 )
             }}

          {:error, changeset} ->
            msg = format_changeset_errors(changeset)

            {:error,
             dgettext("commands", "[BotService] Failed to add command '%{trigger}': %{message}",
               trigger: trigger,
               message: msg
             )}
        end
    end
  end

  @spec do_delete_command(String.t(), String.t()) :: Handler.result()
  defp do_delete_command(bot_name, trigger) do
    case Queries.get_bot_by_name(bot_name) do
      nil ->
        {:error, dgettext("commands", "[BotService] Bot '%{name}' not found.", name: bot_name)}

      bot ->
        Queries.remove_custom_command(bot.id, trigger)
        reload_bot_commands(bot)

        {:ok, :system,
         %{
           content:
             dgettext("commands", "[BotService] Command '%{trigger}' removed from %{name}.",
               trigger: trigger,
               name: bot_name
             )
         }}
    end
  end

  @spec reload_bot_commands(map()) :: :ok
  defp reload_bot_commands(bot) do
    notify_bot_if_running(bot.nickname, fn nickname ->
      commands = Queries.list_custom_commands(bot.id)

      cmd_map =
        Map.new(commands, fn cmd ->
          {cmd.trigger,
           %{
             "response" => cmd.response,
             "description" => cmd.description || "",
             "enabled" => cmd.enabled
           }}
        end)

      Server.reload_commands(nickname, cmd_map)
    end)
  end

  @spec reload_bot_capabilities(map()) :: :ok
  defp reload_bot_capabilities(bot) do
    notify_bot_if_running(bot.nickname, fn nickname ->
      fresh = Queries.get_bot_by_name(bot.name)
      if fresh, do: Server.reload_capabilities(nickname, fresh.capabilities)
    end)
  end

  @spec maybe_update_running(String.t(), map()) :: :ok
  defp maybe_update_running(nickname, updates) do
    notify_bot_if_running(nickname, &Server.update_config(&1, updates))
  end

  defp notify_bot_if_running(nickname, fun) do
    case RetroHexChat.Bots.Registry.lookup(nickname) do
      {:ok, _} -> fun.(nickname)
      {:error, :not_found} -> :ok
    end
  end

  @spec format_bot_list() :: String.t()
  defp format_bot_list do
    case Queries.list_bots() do
      [] ->
        dgettext("commands", "[BotService] No bots configured.")

      bots ->
        lines =
          [dgettext("commands", "[BotService] Bots:")] ++ Enum.map(bots, &format_bot_entry/1)

        Enum.join(lines, "\n")
    end
  end

  defp format_bot_entry(bot) do
    status = if bot.enabled, do: dgettext("commands", "ON"), else: dgettext("commands", "OFF")
    description = bot.description || dgettext("commands", "No description")

    dgettext("commands", "  %{name} [%{status}] — %{description}",
      name: bot.name,
      status: status,
      description: description
    )
  end

  @spec format_changeset_errors(Ecto.Changeset.t()) :: String.t()
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      dgettext("commands", "%{field}: %{errors}", field: field, errors: Enum.join(errors, ", "))
    end)
    |> Enum.join("; ")
  end

  @spec ensure_hash(String.t()) :: String.t()
  defp ensure_hash("#" <> _ = channel), do: channel
  defp ensure_hash(channel), do: "#" <> channel

  @spec maybe_add_description([String.t()], String.t() | nil) :: [String.t()]
  defp maybe_add_description(lines, nil), do: lines

  defp maybe_add_description(lines, desc),
    do: lines ++ [dgettext("commands", "  Description: %{desc}", desc: desc)]

  @spec help_text() :: String.t()
  defp help_text do
    """
    [BotService] Bot Commands:
      /bot create <name> [description] — Create a new bot
      /bot destroy <name> — Delete a bot
      /bot list — List all bots
      /bot info <name> — Show bot details
      /bot join <bot> <channel> — Add bot to channel
      /bot part <bot> <channel> — Remove bot from channel
      /bot enable <bot> — Enable a bot
      /bot disable <bot> — Disable a bot
      /bot set <bot> <key> <value> — Change bot setting
      /bot commands <bot> — List bot's custom commands
      /bot addcmd <bot> <trigger> <response> — Add custom command
      /bot delcmd <bot> <trigger> — Remove custom command
    Settings: prefix, cooldown, description, greeting, farewell, mention_response,
      dice_max_dice, dice_max_sides, dice_default,
      mod_words, mod_action, mod_spam, mod_flood, mod_warn,
      trivia_category, trivia_time, trivia_questions, trivia_points,
      sched_max, sched_min_interval,
      rss_interval, rss_max_feeds, rss_max_items,
      arcade_enabled\
    """
  end
end

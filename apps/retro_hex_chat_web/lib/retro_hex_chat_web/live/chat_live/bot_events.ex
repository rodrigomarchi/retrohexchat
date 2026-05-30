defmodule RetroHexChatWeb.ChatLive.BotEvents do
  @moduledoc """
  Handle bot management dialog events.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [system_event: 2, error_event: 2]

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Bots.Capabilities.{CustomCommands, Dice, Greeter, Help, Mention, Moderation}
  alias RetroHexChat.Bots.Capabilities.{RSS, Scheduler, Trivia}
  alias RetroHexChat.Bots.{Lifecycle, Queries, Server, Supervisor}

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}

  def handle_event("open_bot_dialog", _params, socket) do
    session = socket.assigns.session

    if admin?(session) do
      bots = Queries.list_bots()
      {:halt, assign(socket, show_bot_dialog: true, bot_dialog_bots: bots)}
    else
      {:halt, error_event(socket, "Bot management is restricted to server administrators.")}
    end
  end

  def handle_event("close_bot_dialog", _params, socket) do
    {:halt, assign(socket, show_bot_dialog: false)}
  end

  def handle_event("bot_select", %{"name" => name}, socket) do
    bot = Queries.get_bot_by_name(name)

    if bot do
      channels = Queries.list_channel_configs(bot.id)
      commands = Queries.list_custom_commands(bot.id)
      events = Queries.list_event_logs(bot.id, limit: 50)
      stats = fetch_runtime_stats(bot.nickname)

      {:halt,
       assign(socket,
         bot_dialog_selected: bot,
         bot_dialog_channels: channels,
         bot_dialog_commands: commands,
         bot_dialog_events: events,
         bot_dialog_stats: stats,
         bot_dialog_tab: :general
       )}
    else
      {:halt, socket}
    end
  end

  def handle_event("bot_dialog_tab", %{"tab" => tab}, socket) do
    {:halt, assign(socket, bot_dialog_tab: String.to_existing_atom(tab))}
  end

  def handle_event("bot_toggle_enabled", %{"name" => name}, socket) do
    bot = Queries.get_bot_by_name(name)

    if bot do
      new_enabled = !bot.enabled
      Queries.update_bot(bot, %{enabled: new_enabled})

      notify_bot_if_running(bot.nickname, &Server.set_enabled(&1, new_enabled))

      bots = Queries.list_bots()
      action = if new_enabled, do: "enabled", else: "disabled"

      {:halt,
       socket
       |> assign(bot_dialog_bots: bots)
       |> system_event("[BotService] Bot '#{name}' #{action}.")}
    else
      {:halt, socket}
    end
  end

  def handle_event("bot_delete", %{"name" => name}, socket) do
    bot = Queries.get_bot_by_name(name)

    if bot do
      Lifecycle.destroy_bot(bot)
      bots = Queries.list_bots()

      {:halt,
       socket
       |> assign(
         bot_dialog_bots: bots,
         bot_dialog_selected: nil,
         bot_dialog_channels: [],
         bot_dialog_commands: []
       )
       |> system_event("[BotService] Bot '#{name}' destroyed.")}
    else
      {:halt, socket}
    end
  end

  def handle_event("open_new_bot_dialog", _params, socket) do
    {:halt, assign(socket, show_new_bot_dialog: true)}
  end

  def handle_event("close_new_bot_dialog", _params, socket) do
    {:halt, assign(socket, show_new_bot_dialog: false)}
  end

  def handle_event("create_bot", params, socket) do
    name = Map.get(params, "name", "") |> String.trim()
    nickname = Map.get(params, "nickname", name) |> String.trim()
    description = Map.get(params, "description", "") |> String.trim()
    prefix = Map.get(params, "prefix", "!") |> String.trim()
    cooldown_seconds = Map.get(params, "cooldown", "3") |> parse_int(3)
    cooldown = cooldown_seconds * 1000

    default_caps = build_default_capabilities(params)

    description = if description == "", do: nil, else: description

    attrs = %{
      name: name,
      nickname: if(nickname == "", do: name, else: nickname),
      description: description,
      command_prefix: if(prefix == "", do: "!", else: prefix),
      cooldown_ms: cooldown,
      created_by: socket.assigns.session.nickname,
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
        bots = Queries.list_bots()

        {:halt,
         socket
         |> assign(show_new_bot_dialog: false, bot_dialog_bots: bots)
         |> system_event("[BotService] Bot '#{name}' created.")}

      {:error, changeset} ->
        msg = format_changeset_errors(changeset)
        {:halt, error_event(socket, "[BotService] Failed to create bot '#{name}': #{msg}")}
    end
  end

  def handle_event("bot_add_channel", %{"channel" => channel, "bot_name" => bot_name}, socket) do
    channel = ensure_hash(channel)
    bot = Queries.get_bot_by_name(bot_name)

    if bot do
      handle_add_channel_result(bot, channel, bot_name, socket)
    else
      {:halt, socket}
    end
  end

  def handle_event("bot_remove_channel", %{"channel" => channel, "bot_name" => bot_name}, socket) do
    bot = Queries.get_bot_by_name(bot_name)

    if bot do
      Queries.remove_channel_config(bot.id, channel)
      notify_bot_if_running(bot.nickname, &Server.part_channel(&1, channel))

      channels = Queries.list_channel_configs(bot.id)

      {:halt,
       socket
       |> assign(bot_dialog_channels: channels)
       |> system_event("[BotService] Bot '#{bot_name}' left #{channel}.")}
    else
      {:halt, socket}
    end
  end

  def handle_event("bot_add_command", params, socket) do
    bot_name = Map.get(params, "bot_name", "")
    trigger = Map.get(params, "trigger", "") |> String.trim()
    response = Map.get(params, "response", "") |> String.trim()
    description = Map.get(params, "description", "") |> String.trim()
    bot = Queries.get_bot_by_name(bot_name)

    if bot do
      attrs = %{
        trigger: trigger,
        response: response,
        description: if(description == "", do: nil, else: description),
        added_by: socket.assigns.session.nickname
      }

      case Queries.add_custom_command(bot.id, attrs) do
        {:ok, _} ->
          reload_bot_commands(bot)
          commands = Queries.list_custom_commands(bot.id)

          {:halt,
           socket
           |> assign(bot_dialog_commands: commands, show_add_command_dialog: false)
           |> system_event("[BotService] Command '#{trigger}' added.")}

        {:error, _} ->
          {:halt, error_event(socket, "Command '#{trigger}' already exists.")}
      end
    else
      {:halt, socket}
    end
  end

  def handle_event("bot_remove_command", %{"trigger" => trigger, "bot_name" => bot_name}, socket) do
    bot = Queries.get_bot_by_name(bot_name)

    if bot do
      Queries.remove_custom_command(bot.id, trigger)
      reload_bot_commands(bot)
      commands = Queries.list_custom_commands(bot.id)

      {:halt,
       socket
       |> assign(bot_dialog_commands: commands)
       |> system_event("[BotService] Command '#{trigger}' removed.")}
    else
      {:halt, socket}
    end
  end

  def handle_event("open_add_command_dialog", _params, socket) do
    {:halt, assign(socket, show_add_command_dialog: true)}
  end

  def handle_event("close_add_command_dialog", _params, socket) do
    {:halt, assign(socket, show_add_command_dialog: false)}
  end

  # ── Inline Editing ──

  def handle_event("bot_edit_field", %{"field" => field}, socket) do
    {:halt, assign(socket, bot_dialog_editing_field: String.to_existing_atom(field))}
  end

  def handle_event("bot_cancel_edit", _params, socket) do
    {:halt, assign(socket, bot_dialog_editing_field: nil)}
  end

  def handle_event("bot_update_field", params, socket) do
    bot_name = Map.get(params, "bot_name", "")
    field = Map.get(params, "field", "")
    value = Map.get(params, "value", "") |> String.trim()
    bot = Queries.get_bot_by_name(bot_name)

    if bot do
      handle_field_update(bot, field, value, socket)
    else
      {:halt, error_event(socket, "Bot not found.")}
    end
  end

  # ── Capability Toggle ──

  def handle_event(
        "bot_toggle_capability",
        %{"capability" => cap_name, "bot_name" => bot_name},
        socket
      ) do
    bot = Queries.get_bot_by_name(bot_name)
    {:halt, do_toggle_capability(bot, cap_name, socket)}
  end

  # ── Capability Config Editing ──

  def handle_event("bot_update_cap_config", params, socket) do
    bot_name = Map.get(params, "bot_name", "")
    cap_name = Map.get(params, "capability", "")
    bot = Queries.get_bot_by_name(bot_name)

    if bot do
      caps = bot.capabilities || %{}
      cap_config = Map.get(caps, cap_name, %{})

      # Merge only the provided config fields (exclude meta fields)
      config_updates =
        params
        |> Map.drop(["bot_name", "capability", "_target"])
        |> Enum.into(%{}, fn {k, v} -> {k, coerce_config_value(v)} end)

      new_config = Map.merge(cap_config, config_updates)
      new_caps = Map.put(caps, cap_name, new_config)

      case Queries.update_bot(bot, %{capabilities: new_caps}) do
        {:ok, updated_bot} ->
          restart_bot_if_running(updated_bot)

          {:halt,
           socket
           |> assign(bot_dialog_selected: updated_bot)
           |> system_event("[BotService] #{cap_name} config updated.")}

        {:error, _} ->
          {:halt, error_event(socket, "Failed to update config.")}
      end
    else
      {:halt, socket}
    end
  end

  # ── Per-Channel Toggle ──

  def handle_event("bot_toggle_channel", %{"channel" => channel, "bot_name" => bot_name}, socket) do
    bot = Queries.get_bot_by_name(bot_name)
    {:halt, do_toggle_channel(bot, channel, bot_name, socket)}
  end

  def handle_event(_event, _params, socket) do
    {:cont, socket}
  end

  # ── Helpers ──

  defp handle_add_channel_result(bot, channel, bot_name, socket) do
    case Queries.add_channel_config(bot.id, channel) do
      {:ok, _} ->
        notify_bot_if_running(bot.nickname, &Server.join_channel(&1, channel))
        channels = Queries.list_channel_configs(bot.id)

        {:halt,
         socket
         |> assign(bot_dialog_channels: channels)
         |> system_event("[BotService] Bot '#{bot_name}' joined #{channel}.")}

      {:error, _} ->
        {:halt, error_event(socket, "Bot already in #{channel}.")}
    end
  end

  defp build_default_capabilities(params) do
    cap_checks = [
      {"cap_mention", "mention", &Mention.default_config/0},
      {"cap_greeter", "greeter", &Greeter.default_config/0},
      {"cap_custom_commands", "custom_commands", &CustomCommands.default_config/0},
      {"cap_help", "help", &Help.default_config/0},
      {"cap_dice", "dice", &Dice.default_config/0},
      {"cap_moderation", "moderation", &Moderation.default_config/0},
      {"cap_trivia", "trivia", &Trivia.default_config/0},
      {"cap_scheduler", "scheduler", &Scheduler.default_config/0},
      {"cap_rss", "rss", &RSS.default_config/0}
    ]

    Enum.reduce(cap_checks, %{}, fn {param, name, config_fn}, caps ->
      if params[param] == "true" do
        Map.put(caps, name, config_fn.())
      else
        caps
      end
    end)
  end

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

  defp notify_bot_if_running(nickname, fun) do
    case RetroHexChat.Bots.Registry.lookup(nickname) do
      {:ok, _} -> fun.(nickname)
      {:error, :not_found} -> :ok
    end
  end

  defp handle_field_update(bot, "description", value, socket) do
    desc = if value == "", do: nil, else: value

    case Queries.update_bot(bot, %{description: desc}) do
      {:ok, updated_bot} ->
        {:halt,
         socket
         |> assign(bot_dialog_selected: updated_bot, bot_dialog_editing_field: nil)
         |> system_event("[BotService] Description updated.")}

      {:error, _} ->
        {:halt, error_event(socket, "Failed to update description.")}
    end
  end

  defp handle_field_update(bot, "prefix", value, socket) do
    if value == "" do
      {:halt, error_event(socket, "Prefix cannot be empty.")}
    else
      case Queries.update_bot(bot, %{command_prefix: value}) do
        {:ok, updated_bot} ->
          notify_bot_if_running(bot.nickname, &Server.update_config(&1, %{command_prefix: value}))

          {:halt,
           socket
           |> assign(bot_dialog_selected: updated_bot, bot_dialog_editing_field: nil)
           |> system_event("[BotService] Prefix updated to '#{value}'.")}

        {:error, _} ->
          {:halt, error_event(socket, "Failed to update prefix.")}
      end
    end
  end

  defp handle_field_update(bot, "cooldown", value, socket) do
    case Integer.parse(value) do
      {n, _} when n >= 500 ->
        case Queries.update_bot(bot, %{cooldown_ms: n}) do
          {:ok, updated_bot} ->
            notify_bot_if_running(bot.nickname, &Server.update_config(&1, %{cooldown_ms: n}))

            {:halt,
             socket
             |> assign(bot_dialog_selected: updated_bot, bot_dialog_editing_field: nil)
             |> system_event("[BotService] Cooldown updated to #{n}ms.")}

          {:error, _} ->
            {:halt, error_event(socket, "Failed to update cooldown.")}
        end

      {_, _} ->
        {:halt, error_event(socket, "Cooldown must be at least 500ms.")}

      :error ->
        {:halt, error_event(socket, "Cooldown must be a number.")}
    end
  end

  defp handle_field_update(_bot, _field, _value, socket) do
    {:halt, error_event(socket, "Unknown field.")}
  end

  defp do_toggle_capability(nil, _cap_name, socket), do: socket

  defp do_toggle_capability(bot, cap_name, socket) do
    caps = bot.capabilities || %{}
    cap_config = Map.get(caps, cap_name, %{})
    currently_enabled = Map.get(cap_config, "enabled", true)
    new_config = Map.put(cap_config, "enabled", !currently_enabled)
    new_caps = Map.put(caps, cap_name, new_config)

    case Queries.update_bot(bot, %{capabilities: new_caps}) do
      {:ok, updated_bot} ->
        restart_bot_if_running(updated_bot)
        action = if currently_enabled, do: "disabled", else: "enabled"

        socket
        |> assign(bot_dialog_selected: updated_bot)
        |> system_event("[BotService] Capability '#{cap_name}' #{action}.")

      {:error, _} ->
        error_event(socket, "Failed to update capability.")
    end
  end

  defp do_toggle_channel(nil, _channel, _bot_name, socket), do: socket

  defp do_toggle_channel(bot, channel, bot_name, socket) do
    configs = Queries.list_channel_configs(bot.id)

    case Enum.find(configs, &(&1.channel_name == channel)) do
      nil ->
        socket

      config ->
        new_enabled = !config.enabled
        Queries.update_channel_config(config, %{enabled: new_enabled})
        channels = Queries.list_channel_configs(bot.id)
        action = if new_enabled, do: "enabled", else: "disabled"

        socket
        |> assign(bot_dialog_channels: channels)
        |> system_event("[BotService] #{bot_name} #{action} in #{channel}.")
    end
  end

  defp restart_bot_if_running(bot) do
    case RetroHexChat.Bots.Registry.lookup(bot.nickname) do
      {:ok, _} ->
        Supervisor.stop_bot(bot.nickname)

        bot_with_assocs = %{
          id: bot.id,
          name: bot.name,
          nickname: bot.nickname,
          command_prefix: bot.command_prefix,
          created_by: bot.created_by,
          enabled: bot.enabled,
          cooldown_ms: bot.cooldown_ms,
          capabilities: bot.capabilities,
          channel_configs: Queries.list_channel_configs(bot.id),
          custom_commands: Queries.list_custom_commands(bot.id)
        }

        Supervisor.start_bot(bot_with_assocs)

      {:error, :not_found} ->
        :ok
    end
  end

  defp coerce_config_value(value) when is_binary(value) do
    case Integer.parse(value) do
      {n, ""} -> n
      _ -> value
    end
  end

  defp coerce_config_value(value), do: value

  defp fetch_runtime_stats(nickname) do
    case Server.get_state(nickname) do
      {:ok, state} -> state.stats
      {:error, :not_found} -> nil
    end
  end

  defp ensure_hash("#" <> _ = ch), do: ch
  defp ensure_hash(ch), do: "#" <> ch

  defp parse_int(str, default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
    |> Enum.join("; ")
  end

  defp admin?(session) do
    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end
end

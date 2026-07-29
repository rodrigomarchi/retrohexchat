defmodule RetroHexChatWeb.ChatLive.BotEvents do
  @moduledoc """
  Handle bot management dialog events.
  """

  import Phoenix.LiveView, only: [send_update: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [system_event: 2, error_event: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Bots.Capabilities.{CustomCommands, Dice, Greeter, Help, Mention, Moderation}
  alias RetroHexChat.Bots.Capabilities.{RSS, Scheduler, Trivia}
  alias RetroHexChat.Bots.{Feeds, Lifecycle, Queries, Server, Supervisor}
  alias RetroHexChatWeb.ChatLive.Components.BotManagementDialog
  alias RetroHexChatWeb.ChatLive.Windows

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}

  def handle_event("open_bot_dialog", _params, socket) do
    session = socket.assigns.session

    if admin?(session) do
      # Managed window: the island loads the bot list itself on mount. The admin
      # gate here is the server-side authorization for a forged window_open.
      {:halt, Windows.open(socket, BotManagementDialog.id())}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Bot management is restricted to server administrators.")
       )}
    end
  end

  def handle_event("bot_select", %{"name" => name}, socket) do
    bot = Queries.get_bot_by_name(name)

    if bot do
      channels = Queries.list_channel_configs(bot.id)
      commands = Queries.list_custom_commands(bot.id)
      events = Queries.list_event_logs(bot.id, limit: 50)
      stats = fetch_runtime_stats(bot.nickname)

      {:halt,
       put_bot(socket,
         selected: bot,
         channels: channels,
         commands: commands,
         events: events,
         stats: stats,
         tab: :general
       )}
    else
      {:halt, socket}
    end
  end

  def handle_event("bot_toggle_enabled", %{"name" => name}, socket) do
    case Queries.get_bot_by_name(name) do
      nil -> {:halt, socket}
      bot -> {:halt, toggle_bot_enabled(bot, socket)}
    end
  end

  def handle_event("bot_delete", %{"name" => name}, socket) do
    bot = Queries.get_bot_by_name(name)

    if bot do
      Lifecycle.destroy_bot(bot)
      bots = Queries.list_bots()

      {:halt,
       socket
       |> put_bot(
         bots: bots,
         selected: nil,
         channels: [],
         commands: []
       )
       |> system_event(dgettext("chat", "[BotService] Bot '%{name}' destroyed.", name: name))}
    else
      {:halt, socket}
    end
  end

  def handle_event("open_new_bot_dialog", _params, socket) do
    {:halt, put_bot(socket, show_new_bot: true)}
  end

  def handle_event("close_new_bot_dialog", _params, socket) do
    {:halt, put_bot(socket, show_new_bot: false)}
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
         |> put_bot(show_new_bot: false, bots: bots)
         |> system_event(dgettext("chat", "[BotService] Bot '%{name}' created.", name: name))}

      {:error, changeset} ->
        msg = format_changeset_errors(changeset)

        {:halt,
         error_event(
           socket,
           dgettext("chat", "[BotService] Failed to create bot '%{name}': %{message}",
             name: name,
             message: msg
           )
         )}
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
       |> put_bot(channels: channels)
       |> system_event(
         dgettext("chat", "[BotService] Bot '%{name}' left %{channel}.",
           name: bot_name,
           channel: channel
         )
       )}
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
           |> put_bot(commands: commands, show_add_command: false)
           |> system_event(
             dgettext("chat", "[BotService] Command '%{trigger}' added.", trigger: trigger)
           )}

        {:error, _} ->
          {:halt,
           error_event(
             socket,
             dgettext("chat", "Command '%{trigger}' already exists.", trigger: trigger)
           )}
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
       |> put_bot(commands: commands)
       |> system_event(
         dgettext("chat", "[BotService] Command '%{trigger}' removed.", trigger: trigger)
       )}
    else
      {:halt, socket}
    end
  end

  def handle_event("open_add_command_dialog", _params, socket) do
    {:halt, put_bot(socket, show_add_command: true)}
  end

  def handle_event("close_add_command_dialog", _params, socket) do
    {:halt, put_bot(socket, show_add_command: false)}
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

  # ── RSS feeds ──

  def handle_event(
        "bot_rss_add_feed",
        %{"bot_name" => bot_name, "url" => url, "channel" => channel},
        socket
      ) do
    if admin?(socket.assigns.session) do
      {:halt, do_rss_add(Queries.get_bot_by_name(bot_name), url, channel, socket)}
    else
      {:halt, error_event(socket, dgettext("chat", "Only admins can manage bots."))}
    end
  end

  def handle_event(
        "bot_rss_remove_feed",
        %{"bot_name" => bot_name, "feed_id" => feed_id},
        socket
      ) do
    if admin?(socket.assigns.session) do
      {:halt, do_rss_remove(Queries.get_bot_by_name(bot_name), feed_id, socket)}
    else
      {:halt, error_event(socket, dgettext("chat", "Only admins can manage bots."))}
    end
  end

  def handle_event(_event, _params, socket) do
    {:cont, socket}
  end

  # ── Helpers ──

  # Reflect bot-dialog state to the BotManagementDialog island. `attrs` is a
  # keyword list of the component's owned assigns; returns the socket unchanged so
  # callers keep the `{:halt, socket}` flow and pipe chains.
  @spec put_bot(Phoenix.LiveView.Socket.t(), keyword()) :: Phoenix.LiveView.Socket.t()
  defp put_bot(socket, attrs) do
    send_update(BotManagementDialog, [id: BotManagementDialog.id()] ++ attrs)
    socket
  end

  defp handle_add_channel_result(bot, channel, bot_name, socket) do
    case Queries.add_channel_config(bot.id, channel) do
      {:ok, _} ->
        notify_bot_if_running(bot.nickname, &Server.join_channel(&1, channel))
        channels = Queries.list_channel_configs(bot.id)

        {:halt,
         socket
         |> put_bot(channels: channels)
         |> system_event(
           dgettext("chat", "[BotService] Bot '%{name}' joined %{channel}.",
             name: bot_name,
             channel: channel
           )
         )}

      {:error, _} ->
        {:halt,
         error_event(socket, dgettext("chat", "Bot already in %{channel}.", channel: channel))}
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

  defp do_rss_add(nil, _url, _channel, socket) do
    error_event(socket, dgettext("chat", "[BotService] Bot not found."))
  end

  defp do_rss_add(bot, url, channel, socket) do
    case Feeds.add(bot, url, channel) do
      {:ok, updated} ->
        socket
        |> put_bot(selected: updated)
        |> system_event(
          dgettext("chat", "[BotService] Feed added: %{url} → %{channel}",
            url: url,
            channel: channel
          )
        )

      {:error, reason} ->
        error_event(socket, dgettext("chat", "[BotService] %{reason}", reason: reason))
    end
  end

  defp do_rss_remove(nil, _feed_id, socket) do
    error_event(socket, dgettext("chat", "[BotService] Bot not found."))
  end

  defp do_rss_remove(bot, feed_id, socket) do
    case Feeds.remove(bot, feed_id) do
      {:ok, updated} ->
        socket
        |> put_bot(selected: updated)
        |> system_event(dgettext("chat", "[BotService] Feed removed."))

      {:error, reason} ->
        error_event(socket, dgettext("chat", "[BotService] %{reason}", reason: reason))
    end
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

        action =
          if currently_enabled,
            do: dgettext("chat", "disabled"),
            else: dgettext("chat", "enabled")

        socket
        |> put_bot(selected: updated_bot)
        |> system_event(
          dgettext("chat", "[BotService] Capability '%{capability}' %{action}.",
            capability: cap_name,
            action: action
          )
        )

      {:error, _} ->
        error_event(socket, dgettext("chat", "Failed to update capability."))
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

  @spec toggle_bot_enabled(RetroHexChat.Bots.Bot.t(), Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  defp toggle_bot_enabled(bot, socket) do
    new_enabled = !bot.enabled

    case Queries.update_bot(bot, %{enabled: new_enabled}) do
      {:ok, updated_bot} ->
        notify_bot_if_running(bot.nickname, &Server.set_enabled(&1, new_enabled))

        action =
          if new_enabled, do: dgettext("chat", "enabled"), else: dgettext("chat", "disabled")

        socket
        |> put_bot(bots: Queries.list_bots(), selected: updated_bot)
        |> system_event(
          dgettext("chat", "[BotService] Bot '%{name}' %{action}.",
            name: bot.name,
            action: action
          )
        )

      {:error, _changeset} ->
        error_event(socket, dgettext("chat", "Failed to update bot status."))
    end
  end

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
    |> Enum.map(fn {field, errors} ->
      dgettext("chat", "%{field}: %{errors}",
        field: to_string(field),
        errors: Enum.join(errors, ", ")
      )
    end)
    |> Enum.join("; ")
  end

  defp admin?(session) do
    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end
end

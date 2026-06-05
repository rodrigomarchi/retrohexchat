defmodule RetroHexChatWeb.ChatLive.AdminConsoleEvents do
  @moduledoc """
  Handle Admin Console dialog events: open, close, execute batch commands, clear results.

  Commands are executed sequentially and context flows between them — e.g. `/join #general`
  updates `active_channel` so the next `/cs register` operates on `#general`.
  """

  import Phoenix.Component, only: [assign: 2]
  import RetroHexChatWeb.ChatLive.Helpers, only: [error_event: 2]

  use Gettext, backend: RetroHexChatWeb.Gettext

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Admin
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChat.Services.Motd
  alias RetroHexChatWeb.ChatLive.CommandDispatch

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont | :halt, Phoenix.LiveView.Socket.t()}

  def handle_event("open_admin_console", _params, socket) do
    if admin?(socket) do
      {:halt,
       assign(socket,
         show_admin_console: true,
         admin_console_results: [],
         admin_console_tab: "console",
         admin_console_motd_result: nil,
         admin_console_broadcast_result: nil,
         admin_console_turn_result: nil,
         admin_console_audit_log_result: nil,
         admin_console_server_settings_result: nil,
         admin_console_users_result: nil,
         admin_console_danger_zone_result: nil,
         admin_console_danger_zone_confirm: ""
       )}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("close_admin_console", _params, socket) do
    {:halt, assign(socket, show_admin_console: false)}
  end

  def handle_event("admin_console_tab", %{"tab" => tab}, socket) do
    tab = normalize_tab(tab)
    socket = assign(socket, admin_console_tab: tab)

    socket =
      case tab do
        "server_settings" -> assign_server_settings_snapshot(socket, nil)
        "users" -> assign_users_snapshot(socket, %{}, nil)
        "motd" -> assign_motd_snapshot(socket, nil)
        "turn" -> assign_turn_snapshot(socket)
        "audit_log" -> assign_audit_log_snapshot(socket, %{})
        "danger_zone" -> assign_nuke_preview(socket, nil)
        _ -> socket
      end

    {:halt, socket}
  end

  def handle_event("admin_console_refresh_users", params, socket) do
    if admin?(socket) do
      {:halt, assign_users_snapshot(socket, params, nil)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_user_info", %{"nick" => nick}, socket) do
    if admin?(socket) do
      nick = String.trim(nick)

      result =
        if nick == "" do
          %{status: :error, message: dgettext("chat", "Enter a nick to inspect.")}
        else
          "admin"
          |> Dispatcher.dispatch(["user", "info", nick], user_context(socket))
          |> result_entry()
        end

      socket =
        socket
        |> assign_users_snapshot(%{}, result)
        |> assign(admin_console_users_info_nick: nick)

      {:halt, socket}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_refresh_motd", _params, socket) do
    if admin?(socket) do
      result = Dispatcher.dispatch("motd", [], user_context(socket))
      {:halt, assign_motd_snapshot(socket, result_entry(result))}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_set_motd", %{"motd" => motd}, socket) do
    if admin?(socket) do
      args =
        motd
        |> String.trim()
        |> motd_args()

      result = Dispatcher.dispatch("setmotd", args, user_context(socket))
      {:halt, assign_motd_snapshot(socket, result_entry(result))}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_clear_motd", _params, socket) do
    if admin?(socket) do
      result = Dispatcher.dispatch("clearmotd", [], user_context(socket))
      {:halt, assign_motd_snapshot(socket, result_entry(result))}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event(
        "admin_console_send_broadcast",
        %{"broadcast_type" => type, "message" => message},
        socket
      ) do
    if admin?(socket) do
      command = broadcast_command(type)

      args =
        message
        |> String.trim()
        |> command_args()

      result = Dispatcher.dispatch(command, args, user_context(socket))
      {:halt, assign(socket, admin_console_broadcast_result: result_entry(result))}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_refresh_turn", _params, socket) do
    if admin?(socket) do
      {:halt, assign_turn_snapshot(socket)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_refresh_audit_log", params, socket) do
    if admin?(socket) do
      {:halt, assign_audit_log_snapshot(socket, params)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_refresh_server_settings", _params, socket) do
    if admin?(socket) do
      {:halt, assign_server_settings_snapshot(socket, nil)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_save_server_settings", params, socket) do
    if admin?(socket) do
      current =
        Map.get(
          socket.assigns,
          :admin_console_server_settings_values,
          Admin.server_settings_values()
        )

      changes = Admin.server_setting_changes(current, server_settings_params(params))
      result = save_server_settings(changes, socket)
      {:halt, assign_server_settings_snapshot(socket, result)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_start_singleplayer", _params, socket) do
    if admin?(socket) do
      {socket, result} =
        CommandDispatch.dispatch_command_with_result(
          socket,
          socket.assigns.session,
          "singleplayer",
          []
        )

      {:halt, assign(socket, admin_console_server_settings_result: result_entry(result))}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_preview_nuke", _params, socket) do
    if admin?(socket) do
      {:halt, assign_nuke_preview(socket, nil)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_change_nuke_confirm", %{"confirm" => confirm}, socket) do
    {:halt, assign(socket, admin_console_danger_zone_confirm: confirm)}
  end

  def handle_event("admin_console_execute_nuke", %{"confirm" => confirm}, socket) do
    if admin?(socket) do
      if confirm == nuke_server_name(socket) do
        result = Dispatcher.dispatch("admin", ["nuke", "--confirm"], user_context(socket))

        {:halt,
         assign(socket,
           admin_console_danger_zone_preview: result_message(result),
           admin_console_danger_zone_result: result_entry(result),
           admin_console_danger_zone_confirm: ""
         )}
      else
        {:halt,
         assign(socket,
           admin_console_danger_zone_confirm: confirm,
           admin_console_danger_zone_result: %{
             status: :error,
             message: dgettext("chat", "Type the server name to confirm.")
           }
         )}
      end
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("execute_admin_console", %{"input" => input}, socket) do
    if admin?(socket) do
      results = execute_batch(input, socket)
      {:halt, assign(socket, admin_console_results: results)}
    else
      {:halt,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("clear_admin_console", _params, socket) do
    {:halt, assign(socket, admin_console_results: [])}
  end

  def handle_event(_event, _params, socket), do: {:cont, socket}

  # ── Private ──────────────────────────────────────────────

  defp normalize_tab(tab)
       when tab in ~w(server_settings users channels motd broadcast audit_log turn danger_zone console),
       do: tab

  defp normalize_tab(_tab), do: "console"

  defp execute_batch(input, socket) do
    session = socket.assigns.session

    # Include active_channel in operator_in so /mode works on the initial channel.
    # Use empty channels list to bypass the per-user channel limit — the admin console
    # is a provisioning tool, not a real user session.
    initial_ops = if session.active_channel, do: [session.active_channel], else: []

    context = %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: [],
      identified: session.identified,
      owner_in: initial_ops,
      operator_in: initial_ops,
      half_operator_in: [],
      is_admin: true,
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
    }

    lines =
      input
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(blank?(&1) or comment?(&1)))

    {results, _final_context} =
      Enum.map_reduce(lines, context, fn line, ctx ->
        {result_entry, new_ctx} = execute_line(line, ctx)
        {result_entry, new_ctx}
      end)

    results
  end

  defp assign_motd_snapshot(socket, result) do
    assign(socket,
      admin_console_motd: Motd.get(),
      admin_console_motd_result: result
    )
  end

  defp assign_turn_snapshot(socket) do
    %{stats: stats, allocations: allocations, result: result} = turn_snapshot(socket)

    assign(socket,
      admin_console_turn_stats: stats,
      admin_console_turn_allocations: allocations,
      admin_console_turn_result: result
    )
  end

  defp assign_audit_log_snapshot(socket, params) do
    last =
      normalize_audit_last(Map.get(params, "last", socket.assigns.admin_console_audit_log_last))

    user =
      normalize_audit_user(Map.get(params, "user", socket.assigns.admin_console_audit_log_user))

    result = Dispatcher.dispatch("admin", audit_log_args(last, user), user_context(socket))

    assign(socket,
      admin_console_audit_log_text: result_message(result),
      admin_console_audit_log_last: last,
      admin_console_audit_log_user: user,
      admin_console_audit_log_result: audit_log_result_entry(result)
    )
  end

  defp assign_server_settings_snapshot(socket, result) do
    context = user_context(socket)
    info_result = Dispatcher.dispatch("admin", ["server", "info"], context)
    settings_result = Dispatcher.dispatch("admin", ["server", "settings"], context)

    assign(socket,
      admin_console_server_settings_info: result_message(info_result),
      admin_console_server_settings_text: result_message(settings_result),
      admin_console_server_settings_values: Admin.server_settings_values(),
      admin_console_server_settings_result:
        result || first_error_entry([info_result, settings_result])
    )
  end

  defp assign_users_snapshot(socket, params, result) do
    search = users_search(socket, params)
    online_only = users_online_only(socket, params)
    context = user_context(socket)

    list_result = Dispatcher.dispatch("admin", users_list_args(search, online_only), context)
    banlist_result = Dispatcher.dispatch("admin", users_banlist_args(search), context)

    assign(socket,
      admin_console_users_text: result_message(list_result),
      admin_console_users_banlist_text: result_message(banlist_result),
      admin_console_users_search: search,
      admin_console_users_online_only: online_only,
      admin_console_users_result: result || first_error_entry([list_result, banlist_result])
    )
  end

  defp assign_nuke_preview(socket, result) do
    preview_result = Dispatcher.dispatch("admin", ["nuke"], user_context(socket))

    assign(socket,
      admin_console_danger_zone_preview: result_message(preview_result),
      admin_console_danger_zone_result: result || first_error_entry([preview_result]),
      admin_console_danger_zone_confirm: "",
      admin_console_danger_zone_server_name: nuke_server_name(socket)
    )
  end

  defp turn_snapshot(socket) do
    context = user_context(socket)
    stats_result = Dispatcher.dispatch("admin", ["turn", "stats"], context)
    allocations_result = Dispatcher.dispatch("admin", ["turn", "allocations"], context)

    %{
      stats: result_message(stats_result),
      allocations: result_message(allocations_result),
      result: first_error_entry([stats_result, allocations_result])
    }
  end

  defp audit_log_args(last, ""), do: ["log", "--last", last]
  defp audit_log_args(last, user), do: ["log", "--last", last, "--user", user]

  defp users_list_args(search, online_only) do
    ["user", "list"]
    |> Kernel.++(users_search_args(search))
    |> Kernel.++(users_online_args(online_only))
  end

  defp users_banlist_args(search), do: ["user", "banlist"] ++ users_search_args(search)

  defp users_search_args(""), do: []
  defp users_search_args(search), do: ["--search", search]

  defp users_online_args(true), do: ["--online"]
  defp users_online_args(false), do: []

  defp users_search(_socket, %{"search" => search}), do: normalize_users_search(search)

  defp users_search(socket, _params) do
    socket.assigns
    |> Map.get(:admin_console_users_search, "")
    |> normalize_users_search()
  end

  defp users_online_only(_socket, %{"online_only" => value}), do: truthy_param?(value)

  defp users_online_only(_socket, %{"search" => _search}), do: false

  defp users_online_only(socket, _params) do
    Map.get(socket.assigns, :admin_console_users_online_only, false)
  end

  defp normalize_audit_last(value) do
    case value |> to_string() |> String.trim() do
      "" -> "20"
      last -> last
    end
  end

  defp normalize_audit_user(value) do
    value
    |> to_string()
    |> String.trim()
  end

  defp normalize_users_search(value) do
    value
    |> to_string()
    |> String.trim()
  end

  defp truthy_param?(value), do: value in [true, "true", "on", "1", 1]

  defp audit_log_result_entry(result) do
    if result_status(result) == :error, do: result_entry(result), else: nil
  end

  defp server_settings_params(params) do
    params
    |> Map.take(Admin.server_setting_keys())
    |> Map.new(fn {key, value} -> {key, to_string(value)} end)
  end

  defp save_server_settings([], _socket) do
    %{status: :ok, message: dgettext("chat", "No server settings changed.")}
  end

  defp save_server_settings(changes, socket) do
    results =
      Enum.map(changes, fn {key, value} ->
        Dispatcher.dispatch("admin", ["server", "set", key, value], user_context(socket))
      end)

    %{
      status: if(Enum.any?(results, &(result_status(&1) == :error)), do: :error, else: :ok),
      message: Enum.map_join(results, "\n", &result_message/1)
    }
  end

  defp nuke_server_name(_socket) do
    Admin.server_settings_values()
    |> Map.get("server_name", "RetroHexChat")
  end

  defp command_args(""), do: []
  defp command_args(content), do: [content]

  defp motd_args(content), do: command_args(content)

  defp broadcast_command("announce"), do: "announce"
  defp broadcast_command(_type), do: "wallops"

  defp result_entry(result) do
    %{status: result_status(result), message: result_message(result)}
  end

  defp first_error_entry(results) do
    results
    |> Enum.find(&(result_status(&1) == :error))
    |> case do
      nil -> nil
      result -> result_entry(result)
    end
  end

  defp user_context(socket) do
    session = socket.assigns.session

    %{
      nickname: session.nickname,
      active_channel: session.active_channel,
      channels: session.channels,
      identified: session.identified,
      owner_in: [],
      operator_in: [],
      half_operator_in: [],
      is_admin: ServerRoles.admin?(session.nickname, session.identified),
      is_server_operator: ServerRoles.server_operator?(session.nickname, session.identified)
    }
  end

  defp execute_line(line, context) do
    case Parser.parse(line) do
      {:command, name, args} ->
        result = Dispatcher.dispatch(name, args, context)
        new_ctx = apply_side_effects(result, context)
        entry = %{line: line, status: result_status(result), message: result_message(result)}
        {entry, new_ctx}

      {:message, _text} ->
        entry = %{
          line: line,
          status: :error,
          message: dgettext("chat", "Not a command (must start with /)")
        }

        {entry, context}
    end
  end

  # When /join succeeds, actually join the channel server-side and update context
  defp apply_side_effects({:ok, :join, channel_name}, ctx) do
    do_join_channel(channel_name, ctx)
  end

  defp apply_side_effects({:ok, :join, channel_name, _password}, ctx) do
    do_join_channel(channel_name, ctx)
  end

  # When /topic set is dispatched, execute the topic change server-side
  defp apply_side_effects({:ok, :ui_action, :set_topic, %{channel: ch, topic: topic}}, ctx) do
    Server.set_topic(ch, ctx.nickname, topic)
    ctx
  end

  # When /mode is dispatched, execute the mode change server-side
  defp apply_side_effects(
         {:ok, :ui_action, :set_mode, %{channel: ch, mode_string: ms, params: params}},
         ctx
       ) do
    Server.set_mode(ch, ctx.nickname, ms, params)
    ctx
  end

  defp apply_side_effects(_result, ctx), do: ctx

  defp do_join_channel(channel_name, ctx) do
    ensure_channel_exists(channel_name)
    Server.join(channel_name, ctx.nickname, nil, identified: ctx.identified)

    %{
      ctx
      | active_channel: channel_name,
        channels: Enum.uniq([channel_name | ctx.channels]),
        owner_in: Enum.uniq([channel_name | ctx.owner_in]),
        operator_in: Enum.uniq([channel_name | ctx.operator_in])
    }
  end

  @spec ensure_channel_exists(String.t()) :: :ok | {:error, term()}
  defp ensure_channel_exists(channel_name) do
    case Registry.lookup(channel_name) do
      {:ok, _pid} -> :ok
      {:error, :not_found} -> start_channel(channel_name)
    end
  end

  defp start_channel(channel_name) do
    case Supervisor.start_child(channel_name) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp result_status({:error, _}), do: :error
  defp result_status(_), do: :ok

  defp result_message({:ok, :system, %{content: text}}), do: text

  defp result_message({:ok, :join, channel}),
    do: dgettext("chat", "Joined %{channel}", channel: channel)

  defp result_message({:ok, :join, channel, _pw}),
    do: dgettext("chat", "Joined %{channel}", channel: channel)

  defp result_message({:ok, :ui_action, :set_topic, %{topic: t}}),
    do: dgettext("chat", "Topic set: %{topic}", topic: t)

  defp result_message({:ok, :ui_action, :set_mode, %{mode_string: m}}),
    do: dgettext("chat", "Mode set: %{mode}", mode: m)

  defp result_message({:ok, :ui_action, :show_motd, %{content: text}}), do: text

  defp result_message({:ok, :ui_action, :view_topic, _}), do: dgettext("chat", "Done")
  defp result_message({:error, msg}), do: msg

  defp result_message({:ok, _type, payload}) when is_map(payload) do
    payload
    |> Map.get(:content, Map.get(payload, :message, dgettext("chat", "Done")))
    |> to_string()
  end

  defp result_message(_), do: dgettext("chat", "Done")

  defp blank?(""), do: true
  defp blank?(_), do: false

  defp comment?("#" <> _), do: true
  defp comment?(_), do: false

  defp admin?(socket) do
    session = socket.assigns.session

    ServerRoles.admin?(session.nickname, session.identified) or
      ServerRoles.server_operator?(session.nickname, session.identified)
  end
end

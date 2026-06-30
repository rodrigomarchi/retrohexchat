defmodule RetroHexChatWeb.ChatLive.Components.AdminConsoleDialog do
  @moduledoc """
  Stateful island for the Admin Console mini-app — owns the ENTIRE console: all
  display/result state, the seven filter/draft read-model strings, every event
  (`@myself`), and the privileged `Admin`/`Dispatcher`/`Server` work. Nothing
  about it lives in `ChatLive` anymore — the parent only routes open via
  `send_update` and the design-system dialog owns its own close/Escape.

  Every UI event targets this component (`phx-target={@myself}` threaded through
  `RetroHexChatWeb.Components.UI.AdminConsoleDialog`), so the filter/draft strings
  the action handlers read back to preserve a filter across an action live here
  too (no parent read-model). System-error lines that belong to the chat surface
  bubble via `send(self(), {:admin_system_error, msg})`; the parent runs
  `error_event`. Permissions are derived from the passthrough `session` in
  `render/1` (`is_admin`/`admin_only`/`root_admin` for the per-control flags).
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminConsoleDialog

  alias Phoenix.LiveView.JS
  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Admin
  alias RetroHexChat.Channels.{Registry, Server, Supervisor}
  alias RetroHexChat.Commands.{Dispatcher, Parser}
  alias RetroHexChat.Services.Motd
  alias RetroHexChatWeb.ChatLive.ChatContext
  alias RetroHexChatWeb.ChatLive.CommandDispatch

  @id "admin-console-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @owned_defaults %{
    show: false,
    active_tab: "console",
    results: [],
    motd_content: nil,
    motd_result: nil,
    broadcast_result: nil,
    turn_stats: nil,
    turn_allocations: nil,
    turn_result: nil,
    audit_log_text: nil,
    audit_log_result: nil,
    audit_log_last: "20",
    audit_log_user: "",
    server_settings_info: nil,
    server_settings_text: nil,
    server_settings_values: %{},
    server_settings_result: nil,
    users_text: nil,
    users_banlist_text: nil,
    users_result: nil,
    users_search: "",
    users_online_only: false,
    users_info_nick: "",
    channels_text: nil,
    channels_banlist_text: nil,
    channels_result: nil,
    channels_search: "",
    channels_info_channel: "",
    channels_create_name: "",
    danger_zone_preview: nil,
    danger_zone_result: nil,
    danger_zone_confirm: "",
    danger_zone_server_name: "RetroHexChat",
    admin_console_users_search: "",
    admin_console_users_online_only: false,
    admin_console_channels_search: "",
    admin_console_channels_info_channel: "",
    admin_console_channels_create_name: "",
    admin_console_audit_log_last: "20",
    admin_console_audit_log_user: ""
  }

  @reset %{
    show: true,
    results: [],
    active_tab: "console",
    motd_result: nil,
    broadcast_result: nil,
    turn_result: nil,
    audit_log_result: nil,
    server_settings_result: nil,
    users_result: nil,
    channels_result: nil,
    danger_zone_result: nil,
    danger_zone_confirm: ""
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, socket |> assign(:id, @id) |> assign(@owned_defaults) |> assign(session: nil)}
  end

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{open: true}, socket), do: {:ok, assign(socket, @reset)}
  def update(%{close: true}, socket), do: {:ok, assign(socket, show: false)}
  def update(assigns, socket), do: {:ok, assign(socket, assigns)}

  def handle_event("admin_console_tab", %{"tab" => tab}, socket) do
    tab = normalize_tab(tab)
    socket = put_console(socket, active_tab: tab)

    socket =
      case tab do
        "server_settings" -> assign_server_settings_snapshot(socket, nil)
        "users" -> assign_users_snapshot(socket, %{}, nil)
        "channels" -> assign_channels_snapshot(socket, %{}, nil)
        "motd" -> assign_motd_snapshot(socket, nil)
        "turn" -> assign_turn_snapshot(socket)
        "audit_log" -> assign_audit_log_snapshot(socket, %{})
        "danger_zone" -> assign_nuke_preview(socket, nil)
        _ -> socket
      end

    {:noreply, socket}
  end

  def handle_event("admin_console_refresh_users", params, socket) do
    if admin?(socket) do
      {:noreply, assign_users_snapshot(socket, params, nil)}
    else
      {:noreply,
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
        |> put_console(users_info_nick: nick)

      {:noreply, socket}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_user_ban", params, socket) do
    handle_user_moderation(socket, "ban", params)
  end

  def handle_event("admin_console_user_unban", params, socket) do
    handle_user_moderation(socket, "unban", params)
  end

  def handle_event("admin_console_user_kick", params, socket) do
    handle_user_moderation(socket, "kick", params)
  end

  def handle_event("admin_console_user_mute", params, socket) do
    handle_user_moderation(socket, "mute", params)
  end

  def handle_event("admin_console_user_unmute", params, socket) do
    handle_user_moderation(socket, "unmute", params)
  end

  def handle_event("admin_console_user_rename", params, socket) do
    handle_user_account_action(socket, fn -> user_rename_result(socket, params) end)
  end

  def handle_event("admin_console_user_role", params, socket) do
    handle_user_account_action(socket, fn -> user_role_result(socket, params) end)
  end

  def handle_event("admin_console_user_ns_info", params, socket) do
    handle_user_account_action(socket, fn -> nickserv_result(socket, "info", params) end)
  end

  def handle_event("admin_console_user_ns_drop", params, socket) do
    handle_user_account_action(socket, fn -> nickserv_result(socket, "drop", params) end)
  end

  def handle_event("admin_console_user_ns_resetpass", params, socket) do
    handle_user_account_action(socket, fn -> nickserv_resetpass_result(socket, params) end)
  end

  def handle_event("admin_console_refresh_channels", params, socket) do
    if admin?(socket) do
      {:noreply, assign_channels_snapshot(socket, params, nil)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_channel_info", %{"channel" => channel}, socket) do
    if admin?(socket) do
      channel = String.trim(channel)

      result =
        if channel == "" do
          %{status: :error, message: dgettext("chat", "Enter a channel to inspect.")}
        else
          "admin"
          |> Dispatcher.dispatch(["channel", "info", channel], user_context(socket))
          |> result_entry()
        end

      {:noreply, assign_channels_snapshot(socket, %{"info_channel" => channel}, result)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_channel_create", %{"channel" => channel}, socket) do
    if admin?(socket) do
      channel = String.trim(channel)

      result =
        if channel == "" do
          %{status: :error, message: dgettext("chat", "Enter a channel to create.")}
        else
          "admin"
          |> Dispatcher.dispatch(["channel", "create", channel], user_context(socket))
          |> result_entry()
        end

      {:noreply, assign_channels_snapshot(socket, %{"create_channel" => channel}, result)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_channel_delete", params, socket) do
    handle_channel_destructive_action(socket, "delete", params)
  end

  def handle_event("admin_console_channel_purge", params, socket) do
    handle_channel_destructive_action(socket, "purge", params)
  end

  def handle_event("admin_console_channel_cs_info", params, socket) do
    handle_channel_chanserv_action(
      socket,
      fn -> channel_cs_result(socket, "info", params) end,
      params
    )
  end

  def handle_event("admin_console_channel_cs_drop", params, socket) do
    handle_channel_chanserv_action(socket, fn -> channel_cs_drop_result(socket, params) end, %{
      "info_channel" => ""
    })
  end

  def handle_event("admin_console_channel_cs_transfer", params, socket) do
    handle_channel_chanserv_action(
      socket,
      fn -> channel_cs_transfer_result(socket, params) end,
      params
    )
  end

  def handle_event("admin_console_channel_cs_access_list", params, socket) do
    handle_channel_chanserv_action(
      socket,
      fn -> channel_cs_access_list_result(socket, params) end,
      params
    )
  end

  def handle_event("admin_console_channel_cs_access_add", params, socket) do
    handle_channel_chanserv_action(
      socket,
      fn -> channel_cs_access_result(socket, "add", params) end,
      params
    )
  end

  def handle_event("admin_console_channel_cs_access_del", params, socket) do
    handle_channel_chanserv_action(
      socket,
      fn -> channel_cs_access_result(socket, "del", params) end,
      params
    )
  end

  def handle_event("admin_console_refresh_motd", _params, socket) do
    if admin?(socket) do
      result = Dispatcher.dispatch("motd", [], user_context(socket))
      {:noreply, assign_motd_snapshot(socket, result_entry(result))}
    else
      {:noreply,
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
      {:noreply, assign_motd_snapshot(socket, result_entry(result))}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_clear_motd", _params, socket) do
    if admin?(socket) do
      result = Dispatcher.dispatch("clearmotd", [], user_context(socket))
      {:noreply, assign_motd_snapshot(socket, result_entry(result))}
    else
      {:noreply,
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
      {:noreply, put_console(socket, broadcast_result: result_entry(result))}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_refresh_turn", _params, socket) do
    if admin?(socket) do
      {:noreply, assign_turn_snapshot(socket)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_refresh_audit_log", params, socket) do
    if admin?(socket) do
      {:noreply, assign_audit_log_snapshot(socket, params)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_refresh_server_settings", _params, socket) do
    if admin?(socket) do
      {:noreply, assign_server_settings_snapshot(socket, nil)}
    else
      {:noreply,
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
      {:noreply, assign_server_settings_snapshot(socket, result)}
    else
      {:noreply,
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

      {:noreply, put_console(socket, server_settings_result: result_entry(result))}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_preview_nuke", _params, socket) do
    if admin?(socket) do
      {:noreply, assign_nuke_preview(socket, nil)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("admin_console_change_nuke_confirm", %{"confirm" => confirm}, socket) do
    {:noreply, put_console(socket, danger_zone_confirm: confirm)}
  end

  def handle_event("admin_console_execute_nuke", %{"confirm" => confirm}, socket) do
    if admin?(socket) do
      if confirm == nuke_server_name(socket) do
        result = Dispatcher.dispatch("admin", ["nuke", "--confirm"], user_context(socket))

        {:noreply,
         put_console(socket,
           danger_zone_preview: result_message(result),
           danger_zone_result: result_entry(result),
           danger_zone_confirm: ""
         )}
      else
        {:noreply,
         put_console(socket,
           danger_zone_confirm: confirm,
           danger_zone_result: %{
             status: :error,
             message: dgettext("chat", "Type the server name to confirm.")
           }
         )}
      end
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("execute_admin_console", %{"input" => input}, socket) do
    if admin?(socket) do
      results = execute_batch(input, socket)
      {:noreply, put_console(socket, results: results)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  def handle_event("clear_admin_console", _params, socket) do
    {:noreply, put_console(socket, results: [])}
  end

  # ── Private ──────────────────────────────────────────────

  # Reflect display/result state to the AdminConsoleDialog island. `attrs` is a
  # keyword list of the component's owned assigns; returns the socket unchanged so
  # callers keep the `{:noreply, socket}` flow (and may still `assign/2` the parent's
  # read-model drafts before/after).
  @spec put_console(Phoenix.LiveView.Socket.t(), keyword()) :: Phoenix.LiveView.Socket.t()
  defp put_console(socket, attrs), do: assign(socket, attrs)

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
    put_console(socket,
      motd_content: Motd.get(),
      motd_result: result
    )
  end

  defp assign_turn_snapshot(socket) do
    %{stats: stats, allocations: allocations, result: result} = turn_snapshot(socket)

    put_console(socket,
      turn_stats: stats,
      turn_allocations: allocations,
      turn_result: result
    )
  end

  defp assign_audit_log_snapshot(socket, params) do
    last =
      normalize_audit_last(Map.get(params, "last", socket.assigns.admin_console_audit_log_last))

    user =
      normalize_audit_user(Map.get(params, "user", socket.assigns.admin_console_audit_log_user))

    result = Dispatcher.dispatch("admin", audit_log_args(last, user), user_context(socket))

    # `last`/`user` are the parent read-model (sibling adapters read them back to
    # preserve the filter across an action); display rides to the component.
    socket
    |> assign(admin_console_audit_log_last: last, admin_console_audit_log_user: user)
    |> put_console(
      audit_log_text: result_message(result),
      audit_log_last: last,
      audit_log_user: user,
      audit_log_result: audit_log_result_entry(result)
    )
  end

  defp assign_server_settings_snapshot(socket, result) do
    context = user_context(socket)
    info_result = Dispatcher.dispatch("admin", ["server", "info"], context)
    settings_result = Dispatcher.dispatch("admin", ["server", "settings"], context)

    put_console(socket,
      server_settings_info: result_message(info_result),
      server_settings_text: result_message(settings_result),
      server_settings_values: Admin.server_settings_values(),
      server_settings_result: result || first_error_entry([info_result, settings_result])
    )
  end

  defp assign_users_snapshot(socket, params, result) do
    search = users_search(socket, params)
    online_only = users_online_only(socket, params)
    context = user_context(socket)

    list_result = Dispatcher.dispatch("admin", users_list_args(search, online_only), context)
    banlist_result = Dispatcher.dispatch("admin", users_banlist_args(search), context)

    socket
    |> assign(admin_console_users_search: search, admin_console_users_online_only: online_only)
    |> put_console(
      users_text: result_message(list_result),
      users_banlist_text: result_message(banlist_result),
      users_search: search,
      users_online_only: online_only,
      users_result: result || first_error_entry([list_result, banlist_result])
    )
  end

  defp assign_channels_snapshot(socket, params, result) do
    search = channels_search(socket, params)
    info_channel = channels_info_channel(socket, params)
    create_name = channels_create_name(socket, params)
    context = user_context(socket)

    list_result = Dispatcher.dispatch("admin", channels_list_args(search), context)
    banlist_result = channels_banlist_result(info_channel, context)

    socket
    |> assign(
      admin_console_channels_search: search,
      admin_console_channels_info_channel: info_channel,
      admin_console_channels_create_name: create_name
    )
    |> put_console(
      channels_text: result_message(list_result),
      channels_banlist_text: channels_banlist_text(banlist_result),
      channels_search: search,
      channels_info_channel: info_channel,
      channels_create_name: create_name,
      channels_result: result || first_error_entry([list_result, banlist_result])
    )
  end

  defp assign_nuke_preview(socket, result) do
    preview_result = Dispatcher.dispatch("admin", ["nuke"], user_context(socket))

    put_console(socket,
      danger_zone_preview: result_message(preview_result),
      danger_zone_result: result || first_error_entry([preview_result]),
      danger_zone_confirm: "",
      danger_zone_server_name: nuke_server_name(socket)
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

  defp handle_user_moderation(socket, action, params) do
    if admin?(socket) do
      result = user_moderation_result(socket, action, params)
      {:noreply, assign_users_snapshot(socket, %{}, result)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  defp handle_user_account_action(socket, result_fun) do
    if admin?(socket) do
      result = result_fun.()
      {:noreply, assign_users_snapshot(socket, %{}, result)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  defp user_rename_result(socket, params) do
    old_nick = params |> Map.get("old_nick", "") |> normalize_user_moderation_value()
    new_nick = params |> Map.get("new_nick", "") |> normalize_user_moderation_value()

    cond do
      old_nick == "" -> %{status: :error, message: dgettext("chat", "Enter the current nick.")}
      new_nick == "" -> %{status: :error, message: dgettext("chat", "Enter the new nick.")}
      true -> dispatch_admin_user(socket, ["user", "rename", old_nick, new_nick])
    end
  end

  defp user_role_result(socket, params) do
    nick = params |> Map.get("nick", "") |> normalize_user_moderation_value()
    role = params |> Map.get("role", "") |> normalize_user_moderation_value()

    cond do
      nick == "" -> %{status: :error, message: dgettext("chat", "Enter a nick for this action.")}
      role == "" -> %{status: :error, message: dgettext("chat", "Choose a role.")}
      true -> dispatch_admin_user(socket, ["user", "role", nick, role])
    end
  end

  defp nickserv_result(socket, action, params) do
    nick = params |> Map.get("nick", "") |> normalize_user_moderation_value()

    if nick == "" do
      %{status: :error, message: dgettext("chat", "Enter a nick for this action.")}
    else
      dispatch_admin_user(socket, ["ns", action, nick])
    end
  end

  defp nickserv_resetpass_result(socket, params) do
    nick = params |> Map.get("nick", "") |> normalize_user_moderation_value()
    password = params |> Map.get("new_password", "") |> normalize_user_moderation_value()

    cond do
      nick == "" -> %{status: :error, message: dgettext("chat", "Enter a nick for this action.")}
      password == "" -> %{status: :error, message: dgettext("chat", "Enter a new password.")}
      true -> dispatch_admin_user(socket, ["ns", "resetpass", nick, password])
    end
  end

  defp user_moderation_result(socket, action, params) do
    nick = params |> Map.get("nick", "") |> normalize_user_moderation_value()

    if nick == "" do
      %{status: :error, message: dgettext("chat", "Enter a nick for this action.")}
    else
      "admin"
      |> Dispatcher.dispatch(user_moderation_args(action, nick, params), user_context(socket))
      |> result_entry()
    end
  end

  defp dispatch_admin_user(socket, args) do
    "admin"
    |> Dispatcher.dispatch(args, user_context(socket))
    |> result_entry()
  end

  defp user_moderation_args("ban", nick, params) do
    ["user", "ban", nick]
    |> Kernel.++(user_reason_args(params))
    |> Kernel.++(user_duration_args(params))
  end

  defp user_moderation_args("kick", nick, params) do
    ["user", "kick", nick] ++ user_reason_args(params)
  end

  defp user_moderation_args("mute", nick, params) do
    ["user", "mute", nick] ++ user_duration_args(params)
  end

  defp user_moderation_args(action, nick, _params) when action in ~w(unban unmute) do
    ["user", action, nick]
  end

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

  defp channels_list_args(search), do: ["channel", "list"] ++ channels_search_args(search)

  defp channels_search_args(""), do: []
  defp channels_search_args(search), do: ["--search", search]

  defp channels_banlist_result("", _context), do: nil

  defp channels_banlist_result(channel, context) do
    Dispatcher.dispatch("admin", ["channel", "banlist", channel], context)
  end

  defp channels_banlist_text(nil), do: ""
  defp channels_banlist_text(result), do: result_message(result)

  defp channels_search(_socket, %{"search" => search}), do: normalize_channels_value(search)

  defp channels_search(socket, _params) do
    socket.assigns
    |> Map.get(:admin_console_channels_search, "")
    |> normalize_channels_value()
  end

  defp channels_info_channel(_socket, %{"info_channel" => channel}),
    do: normalize_channels_value(channel)

  defp channels_info_channel(socket, _params) do
    socket.assigns
    |> Map.get(:admin_console_channels_info_channel, "")
    |> normalize_channels_value()
  end

  defp channels_create_name(_socket, %{"create_channel" => channel}),
    do: normalize_channels_value(channel)

  defp channels_create_name(socket, _params) do
    socket.assigns
    |> Map.get(:admin_console_channels_create_name, "")
    |> normalize_channels_value()
  end

  defp handle_channel_destructive_action(socket, action, params) do
    if admin?(socket) do
      channel = params |> Map.get("channel", "") |> normalize_channels_value()
      result = channel_destructive_result(socket, action, channel, params)

      snapshot_params =
        if action == "delete", do: %{"info_channel" => ""}, else: %{"info_channel" => channel}

      {:noreply, assign_channels_snapshot(socket, snapshot_params, result)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  defp channel_destructive_result(_socket, _action, "", _params) do
    %{status: :error, message: dgettext("chat", "Enter a channel for this action.")}
  end

  defp channel_destructive_result(_socket, _action, channel, %{"confirm" => confirm})
       when confirm != channel do
    %{status: :error, message: dgettext("chat", "Type the channel name to confirm.")}
  end

  defp channel_destructive_result(socket, "delete", channel, _params) do
    dispatch_admin_user(socket, ["channel", "delete", channel])
  end

  defp channel_destructive_result(socket, "purge", channel, params) do
    args =
      ["channel", "purge", channel]
      |> Kernel.++(channel_purge_from_args(params))

    dispatch_admin_user(socket, args)
  end

  defp handle_channel_chanserv_action(socket, result_fun, params) do
    if admin?(socket) do
      result = result_fun.()
      {:noreply, assign_channels_snapshot(socket, channel_cs_snapshot_params(params), result)}
    else
      {:noreply,
       error_event(
         socket,
         dgettext("chat", "Admin Console is restricted to server administrators.")
       )}
    end
  end

  defp channel_cs_snapshot_params(%{"info_channel" => _channel} = params), do: params

  defp channel_cs_snapshot_params(params) do
    %{"info_channel" => Map.get(params, "channel", "")}
  end

  defp channel_cs_result(socket, action, params) do
    with {:ok, channel} <- require_channel(params) do
      dispatch_admin_user(socket, ["cs", action, channel])
    end
  end

  defp channel_cs_drop_result(socket, params) do
    with {:ok, channel} <- require_channel(params),
         :ok <- require_channel_confirmation(channel, params) do
      dispatch_admin_user(socket, ["cs", "drop", channel])
    end
  end

  defp channel_cs_transfer_result(socket, params) do
    with {:ok, channel} <- require_channel(params),
         {:ok, nick} <- require_chanserv_nick(params) do
      dispatch_admin_user(socket, ["cs", "transfer", channel, nick])
    end
  end

  defp channel_cs_access_list_result(socket, params) do
    with {:ok, channel} <- require_channel(params) do
      dispatch_admin_user(socket, ["cs", "access", channel])
    end
  end

  defp channel_cs_access_result(socket, action, params) do
    with {:ok, channel} <- require_channel(params),
         {:ok, nick} <- require_chanserv_nick(params),
         {:ok, level} <- require_access_level(params) do
      dispatch_admin_user(socket, ["cs", "access", channel, action, level, nick])
    end
  end

  defp require_channel(params) do
    params
    |> Map.get("channel", "")
    |> normalize_channels_value()
    |> case do
      "" -> %{status: :error, message: dgettext("chat", "Enter a channel for this action.")}
      channel -> {:ok, channel}
    end
  end

  defp require_chanserv_nick(params) do
    params
    |> Map.get("nick", "")
    |> normalize_channels_value()
    |> case do
      "" -> %{status: :error, message: dgettext("chat", "Enter a nick for this action.")}
      nick -> {:ok, nick}
    end
  end

  defp require_access_level(params) do
    params
    |> Map.get("level", "")
    |> normalize_channels_value()
    |> case do
      "" -> %{status: :error, message: dgettext("chat", "Choose an access level.")}
      level -> {:ok, level}
    end
  end

  defp require_channel_confirmation(channel, params) do
    confirm =
      params
      |> Map.get("confirm", "")
      |> normalize_channels_value()

    if confirm == channel do
      :ok
    else
      %{status: :error, message: dgettext("chat", "Type the channel name to confirm.")}
    end
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

  defp normalize_user_moderation_value(value) do
    value
    |> to_string()
    |> String.trim()
  end

  defp normalize_channels_value(value) do
    value
    |> to_string()
    |> String.trim()
  end

  defp truthy_param?(value), do: value in [true, "true", "on", "1", 1]

  defp user_reason_args(params) do
    params
    |> Map.get("reason", "")
    |> normalize_user_moderation_value()
    |> case do
      "" -> []
      reason -> ["--reason", reason]
    end
  end

  defp user_duration_args(params) do
    params
    |> Map.get("duration", "")
    |> normalize_user_moderation_value()
    |> case do
      "" -> []
      duration -> ["--duration", duration]
    end
  end

  defp channel_purge_from_args(params) do
    params
    |> Map.get("from", "")
    |> normalize_channels_value()
    |> case do
      "" -> []
      nick -> ["--from", nick]
    end
  end

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

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    session = assigns.session

    assigns =
      assign(assigns,
        is_admin: ChatContext.admin?(session),
        admin_only: ChatContext.admin_only?(session),
        root_admin: ChatContext.root_admin?(session)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_console_dialog
        id={@id}
        target={@myself}
        show={@show}
        active_tab={@active_tab}
        results={@results}
        motd_content={@motd_content}
        motd_result={@motd_result}
        motd_editable={@admin_only}
        broadcast_result={@broadcast_result}
        broadcast_can_wallops={@is_admin}
        broadcast_can_announce={@admin_only}
        turn_stats={@turn_stats}
        turn_allocations={@turn_allocations}
        turn_result={@turn_result}
        turn_can_refresh={@admin_only}
        audit_log_text={@audit_log_text}
        audit_log_last={@audit_log_last}
        audit_log_user={@audit_log_user}
        audit_log_result={@audit_log_result}
        audit_log_can_refresh={@admin_only}
        server_settings_info={@server_settings_info}
        server_settings_text={@server_settings_text}
        server_settings_values={@server_settings_values}
        server_settings_result={@server_settings_result}
        server_settings_can_edit={@admin_only}
        users_text={@users_text}
        users_banlist_text={@users_banlist_text}
        users_result={@users_result}
        users_search={@users_search}
        users_online_only={@users_online_only}
        users_info_nick={@users_info_nick}
        users_can_refresh={@admin_only}
        users_can_set_admin_role={@root_admin}
        channels_text={@channels_text}
        channels_banlist_text={@channels_banlist_text}
        channels_result={@channels_result}
        channels_search={@channels_search}
        channels_info_channel={@channels_info_channel}
        channels_create_name={@channels_create_name}
        channels_can_refresh={@admin_only}
        danger_zone_preview={@danger_zone_preview}
        danger_zone_result={@danger_zone_result}
        danger_zone_confirm={@danger_zone_confirm}
        danger_zone_server_name={@danger_zone_server_name}
        danger_zone_can_execute={@admin_only}
        on_tab={JS.push("admin_console_tab", target: @myself)}
        on_motd_set="admin_console_set_motd"
        on_motd_clear="admin_console_clear_motd"
        on_motd_refresh="admin_console_refresh_motd"
        on_broadcast_send="admin_console_send_broadcast"
        on_turn_refresh="admin_console_refresh_turn"
        on_audit_log_refresh="admin_console_refresh_audit_log"
        on_server_settings_save="admin_console_save_server_settings"
        on_server_settings_refresh="admin_console_refresh_server_settings"
        on_singleplayer="admin_console_start_singleplayer"
        on_users_refresh="admin_console_refresh_users"
        on_users_info="admin_console_user_info"
        on_users_ban="admin_console_user_ban"
        on_users_unban="admin_console_user_unban"
        on_users_kick="admin_console_user_kick"
        on_users_mute="admin_console_user_mute"
        on_users_unmute="admin_console_user_unmute"
        on_users_rename="admin_console_user_rename"
        on_users_role="admin_console_user_role"
        on_users_ns_info="admin_console_user_ns_info"
        on_users_ns_drop="admin_console_user_ns_drop"
        on_users_ns_resetpass="admin_console_user_ns_resetpass"
        on_channels_refresh="admin_console_refresh_channels"
        on_channels_info="admin_console_channel_info"
        on_channels_create="admin_console_channel_create"
        on_channels_delete="admin_console_channel_delete"
        on_channels_purge="admin_console_channel_purge"
        on_channels_cs_info="admin_console_channel_cs_info"
        on_channels_cs_drop="admin_console_channel_cs_drop"
        on_channels_cs_transfer="admin_console_channel_cs_transfer"
        on_channels_cs_access_list="admin_console_channel_cs_access_list"
        on_channels_cs_access_add="admin_console_channel_cs_access_add"
        on_channels_cs_access_del="admin_console_channel_cs_access_del"
        on_danger_zone_preview="admin_console_preview_nuke"
        on_danger_zone_change="admin_console_change_nuke_confirm"
        on_danger_zone_execute="admin_console_execute_nuke"
        on_close="close_admin_console"
      />
    </div>
    """
  end

  defp error_event(socket, message) do
    send(self(), {:admin_system_error, message})
    socket
  end
end

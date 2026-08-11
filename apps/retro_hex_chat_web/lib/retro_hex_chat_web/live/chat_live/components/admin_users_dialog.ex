defmodule RetroHexChatWeb.ChatLive.Components.AdminUsersDialog do
  @moduledoc """
  Stateful island for the Admin Users window.

  Owns the user list and ban list text, the search filter, the last action's
  result strip, and every privileged `admin user …` / `admin ns …` dispatch.
  Mounted inside a server-managed window: presence in the DOM means open, so
  closing unmounts the island and reopening starts from a fresh snapshot.

  The list loads once, when `session` first arrives — `mount/1` runs before the
  parent passes it, so there is nothing to dispatch with yet. Every action then
  re-reads the snapshot as its result path, which is also what keeps the ban
  list in step with the search filter.

  Permission flags are derived from the passthrough `session` in `render/1`.
  They only disable controls; the handlers re-check with `AdminOps.admin?/1`,
  which is the actual authorization.
  """
  use RetroHexChatWeb, :live_component
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.Components.UI.AdminUsersDialog

  alias RetroHexChat.Table
  alias RetroHexChatWeb.ChatLive.{AdminOps, ChatContext}

  alias RetroHexChatWeb.ChatLive.Components.DialogIsland

  @id "admin-users-dialog"

  @spec id() :: String.t()
  def id, do: @id

  @initial %{
    users_text: nil,
    users_table: nil,
    users_banlist_table: nil,
    users_banlist_text: nil,
    users_result: nil,
    users_search: "",
    users_online_only: false,
    users_info_nick: "",
    loaded?: false
  }

  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket), do: DialogIsland.mount(socket, @id, @initial)

  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket),
    do: DialogIsland.load_once(socket, assigns, &assign_snapshot(&1, %{}, nil))

  # ── List ─────────────────────────────────────────────────────────

  @spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) ::
          {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_event("admin_users_refresh", params, socket) do
    guarded(socket, fn -> {:noreply, assign_snapshot(socket, params, nil)} end)
  end

  @doc """
  Fetches the page after the last nickname on screen and adds it underneath.

  The cursor is a nickname because the listing is ordered alphabetically; asking
  by id would skip and repeat rows.
  """
  def handle_event("admin_users_load_more", _params, socket) do
    guarded(socket, fn ->
      case socket.assigns.users_table && Table.next_cursor(socket.assigns.users_table) do
        nil -> {:noreply, socket}
        cursor -> {:noreply, append_users_page(socket, cursor)}
      end
    end)
  end

  def handle_event("admin_users_info", %{"nick" => nick}, socket) do
    guarded(socket, fn ->
      nick = trim(nick)

      result =
        if nick == "" do
          %{status: :error, message: dgettext("chat", "Enter a nick to inspect.")}
        else
          dispatch(socket, ["user", "info", nick])
        end

      {:noreply,
       socket
       |> assign_snapshot(%{}, result)
       |> assign(users_info_nick: nick)}
    end)
  end

  # ── Moderation ───────────────────────────────────────────────────

  def handle_event("admin_users_ban", params, socket), do: moderate(socket, "ban", params)
  def handle_event("admin_users_unban", params, socket), do: moderate(socket, "unban", params)
  def handle_event("admin_users_kick", params, socket), do: moderate(socket, "kick", params)
  def handle_event("admin_users_mute", params, socket), do: moderate(socket, "mute", params)
  def handle_event("admin_users_unmute", params, socket), do: moderate(socket, "unmute", params)

  # ── Account & roles ──────────────────────────────────────────────

  def handle_event("admin_users_rename", params, socket) do
    act(socket, fn -> rename_result(socket, params) end)
  end

  def handle_event("admin_users_role", params, socket) do
    act(socket, fn -> role_result(socket, params) end)
  end

  # ── NickServ ─────────────────────────────────────────────────────

  def handle_event("admin_users_ns_info", params, socket) do
    act(socket, fn -> nickserv_result(socket, "info", params) end)
  end

  def handle_event("admin_users_ns_drop", params, socket) do
    act(socket, fn -> nickserv_result(socket, "drop", params) end)
  end

  def handle_event("admin_users_ns_resetpass", params, socket) do
    act(socket, fn -> resetpass_result(socket, params) end)
  end

  # ── Render ───────────────────────────────────────────────────────

  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    assigns =
      assign(assigns,
        can_refresh: ChatContext.admin_only?(assigns.session),
        can_set_admin_role: ChatContext.root_admin?(assigns.session)
      )

    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.admin_users_panel
        id={@id}
        target={@myself}
        text={@users_text}
        table={@users_table}
        on_load_more="admin_users_load_more"
        banlist_text={@users_banlist_text}
        banlist_table={@users_banlist_table}
        result={@users_result}
        search={@users_search}
        online_only={@users_online_only}
        info_nick={@users_info_nick}
        can_refresh={@can_refresh}
        can_set_admin_role={@can_set_admin_role}
        on_refresh="admin_users_refresh"
        on_info="admin_users_info"
        on_ban="admin_users_ban"
        on_unban="admin_users_unban"
        on_kick="admin_users_kick"
        on_mute="admin_users_mute"
        on_unmute="admin_users_unmute"
        on_rename="admin_users_rename"
        on_role="admin_users_role"
        on_ns_info="admin_users_ns_info"
        on_ns_drop="admin_users_ns_drop"
        on_ns_resetpass="admin_users_ns_resetpass"
      />
    </div>
    """
  end

  # ── Authorization ────────────────────────────────────────────────

  # Every mutating handler runs through one of these. The disabled controls in
  # the markup are a hint; this is the check that holds against a forged event.
  defp guarded(socket, run) do
    if AdminOps.admin?(socket) do
      run.()
    else
      {:noreply, AdminOps.error_event(socket, AdminOps.restricted_message())}
    end
  end

  defp moderate(socket, action, params) do
    guarded(socket, fn ->
      {:noreply, assign_snapshot(socket, %{}, moderation_result(socket, action, params))}
    end)
  end

  defp act(socket, result_fun) do
    guarded(socket, fn -> {:noreply, assign_snapshot(socket, %{}, result_fun.())} end)
  end

  # ── Snapshot ─────────────────────────────────────────────────────

  # Re-reads both lists under the current filter. `result` is the entry from the
  # action that triggered the refresh; without one, a dispatch failure in either
  # list surfaces instead.
  defp assign_snapshot(socket, params, result) do
    search = search_term(socket, params)
    online_only = online_only?(socket, params)

    list = dispatch_raw(socket, list_args(search, online_only))
    banlist = dispatch_raw(socket, ["user", "banlist"] ++ search_args(search))

    assign(socket,
      users_text: AdminOps.result_message(list),
      users_table: AdminOps.result_table(list),
      users_banlist_text: AdminOps.result_message(banlist),
      users_banlist_table: AdminOps.result_table(banlist),
      users_search: search,
      users_online_only: online_only,
      users_result: result || AdminOps.first_error_entry([list, banlist])
    )
  end

  defp append_users_page(socket, cursor) do
    args =
      list_args(socket.assigns.users_search, socket.assigns.users_online_only) ++
        ["--after", to_string(cursor)]

    result = dispatch_raw(socket, args)

    case AdminOps.result_table(result) do
      %Table{} = next ->
        assign(socket,
          users_table: Table.append(socket.assigns.users_table, next),
          users_result: AdminOps.first_error_entry([result])
        )

      _ ->
        assign(socket, users_result: AdminOps.first_error_entry([result]))
    end
  end

  defp search_term(_socket, %{"search" => search}), do: trim(search)
  defp search_term(socket, _params), do: trim(socket.assigns.users_search)

  defp online_only?(_socket, %{"online_only" => value}), do: value in [true, "true", "on", "1", 1]
  defp online_only?(_socket, %{"search" => _search}), do: false
  defp online_only?(socket, _params), do: socket.assigns.users_online_only

  defp list_args(search, online_only) do
    ["user", "list"] ++ search_args(search) ++ online_args(online_only)
  end

  defp search_args(""), do: []
  defp search_args(search), do: ["--search", search]

  defp online_args(true), do: ["--online"]
  defp online_args(false), do: []

  # ── Action results ───────────────────────────────────────────────

  defp moderation_result(socket, action, params) do
    with_nick(params, fn nick -> dispatch(socket, moderation_args(action, nick, params)) end)
  end

  defp moderation_args("ban", nick, params) do
    ["user", "ban", nick] ++ reason_args(params) ++ duration_args(params)
  end

  defp moderation_args("kick", nick, params), do: ["user", "kick", nick] ++ reason_args(params)
  defp moderation_args("mute", nick, params), do: ["user", "mute", nick] ++ duration_args(params)

  defp moderation_args(action, nick, _params) when action in ~w(unban unmute) do
    ["user", action, nick]
  end

  defp rename_result(socket, params) do
    old_nick = param(params, "old_nick")
    new_nick = param(params, "new_nick")

    cond do
      old_nick == "" -> error_result(dgettext("chat", "Enter the current nick."))
      new_nick == "" -> error_result(dgettext("chat", "Enter the new nick."))
      true -> dispatch(socket, ["user", "rename", old_nick, new_nick])
    end
  end

  defp role_result(socket, params) do
    nick = param(params, "nick")
    role = param(params, "role")

    cond do
      nick == "" -> error_result(dgettext("chat", "Enter a nick for this action."))
      role == "" -> error_result(dgettext("chat", "Choose a role."))
      true -> dispatch(socket, ["user", "role", nick, role])
    end
  end

  defp nickserv_result(socket, action, params) do
    with_nick(params, fn nick -> dispatch(socket, ["ns", action, nick]) end)
  end

  defp resetpass_result(socket, params) do
    nick = param(params, "nick")
    password = param(params, "new_password")

    cond do
      nick == "" -> error_result(dgettext("chat", "Enter a nick for this action."))
      password == "" -> error_result(dgettext("chat", "Enter a new password."))
      true -> dispatch(socket, ["ns", "resetpass", nick, password])
    end
  end

  # ── Dispatch + params ────────────────────────────────────────────

  defp dispatch(socket, args), do: socket |> dispatch_raw(args) |> AdminOps.result_entry()

  defp dispatch_raw(socket, args), do: AdminOps.dispatch(socket, "admin", args)

  # Nearly every action needs the same "a nick is required" guard.
  defp with_nick(params, run) do
    case param(params, "nick") do
      "" -> error_result(dgettext("chat", "Enter a nick for this action."))
      nick -> run.(nick)
    end
  end

  defp reason_args(params), do: flag_args(params, "reason", "--reason")
  defp duration_args(params), do: flag_args(params, "duration", "--duration")

  defp flag_args(params, key, flag) do
    case param(params, key) do
      "" -> []
      value -> [flag, value]
    end
  end

  defp param(params, key), do: params |> Map.get(key, "") |> trim()

  defp trim(value), do: value |> to_string() |> String.trim()

  defp error_result(message), do: %{status: :error, message: message}
end

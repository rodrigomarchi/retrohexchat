defmodule RetroHexChat.Commands.Handlers.Admin.User do
  @moduledoc "Admin subcommands for user management."

  alias RetroHexChat.Accounts.ServerRoles
  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.{AuditLogs, ServerBans}
  alias RetroHexChat.Commands.{Duration, Handler}
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Services.{NickServ, Queries}

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["list" | opts], context) do
    {search, online_only} = parse_list_opts(opts)
    AuditLogs.log(context.nickname, "user.list")
    registered = Queries.list_registered_nicks(search: search)
    online_nicks = online_nicknames()

    entries =
      if online_only do
        Enum.filter(registered, fn n -> n.nickname in online_nicks end)
      else
        registered
      end

    text =
      if entries == [] do
        "*** No users found."
      else
        header = "*** User List (#{length(entries)} results) ***"

        lines = Enum.map(entries, &format_user_entry(&1, online_nicks))

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute(["info", nick], context) do
    nick = strip_at(nick)
    AuditLogs.log(context.nickname, "user.info", {"user", nick})

    case Queries.find_by_nickname(nick) do
      nil ->
        online = nick in online_nicknames()

        text =
          "*** User: #{nick}\n" <>
            "  Registered: no\n" <>
            "  Online: #{online}"

        {:ok, :system, %{content: text}}

      reg ->
        online = nick in online_nicknames()
        identified = NickServ.identified?(nick)
        is_admin = ServerRoles.admin?(nick, identified)
        is_oper = ServerRoles.server_operator?(nick, identified)

        text =
          "*** User: #{nick}\n" <>
            "  Registered: #{reg.registered_at}\n" <>
            "  Last seen: #{reg.last_seen_at}\n" <>
            "  Online: #{online}\n" <>
            "  Identified: #{identified}\n" <>
            "  Admin: #{is_admin}\n" <>
            "  Server operator: #{is_oper}"

        {:ok, :system, %{content: text}}
    end
  end

  def execute(["ban", nick | opts], context) do
    nick = strip_at(nick)
    {reason, duration} = parse_ban_opts(opts)

    case Admin.ban_user(nick, context.nickname, reason, duration) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, msg}
    end
  end

  def execute(["unban", nick], context) do
    nick = strip_at(nick)

    case Admin.unban_user(nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, msg}
    end
  end

  def execute(["kick", nick | opts], context) do
    nick = strip_at(nick)
    reason = parse_reason(opts)

    case Admin.kick_user(nick, context.nickname, reason) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
    end
  end

  def execute(["mute", nick | opts], context) do
    nick = strip_at(nick)
    duration = parse_duration_opt(opts)

    case Admin.mute_user(nick, context.nickname, nil, duration) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
    end
  end

  def execute(["unmute", nick], context) do
    nick = strip_at(nick)

    case Admin.unmute_user(nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
    end
  end

  def execute(["rename", old_nick, new_nick], context) do
    old_nick = strip_at(old_nick)

    case Admin.rename_user(old_nick, new_nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, msg}
    end
  end

  def execute(["role", nick, role], context) do
    nick = strip_at(nick)

    root_admins = Application.get_env(:retro_hex_chat, :root_admins, [])

    if role == "admin" and context.nickname not in root_admins do
      {:error, "Only root admins can promote users to admin"}
    else
      case Admin.set_role(nick, role, context.nickname) do
        {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
        {:error, msg} -> {:error, msg}
      end
    end
  end

  def execute(["banlist" | opts], _context) do
    bans = ServerBans.list_active_bans()
    search = find_opt(opts, "--search")

    filtered =
      if search do
        Enum.filter(bans, fn b -> String.contains?(b.nickname, search) end)
      else
        bans
      end

    text =
      if filtered == [] do
        "*** No active server bans."
      else
        header = "*** Server Ban List (#{length(filtered)}) ***"

        lines = Enum.map(filtered, &format_ban_entry/1)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute([], _context) do
    {:error, "Usage: /admin user <list|info|ban|unban|kick|mute|unmute|rename|role|banlist>"}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown user subcommand: #{subcmd}"}
  end

  # ── Helpers ──────────────────────────────────────────────

  defp format_user_entry(n, online_nicks) do
    online = if n.nickname in online_nicks, do: "online", else: "offline"
    "  #{n.nickname} [registered] [#{online}]"
  end

  defp format_ban_entry(b) do
    expires = if b.expires_at, do: "expires #{b.expires_at}", else: "permanent"
    reason = b.reason || "No reason"
    "  #{b.nickname} — #{reason} (by #{b.banned_by}, #{expires})"
  end

  defp strip_at("@" <> nick), do: nick
  defp strip_at(nick), do: nick

  defp online_nicknames do
    Tracker.list_users("presence:global")
    |> Enum.map(& &1.nickname)
    |> MapSet.new()
  end

  defp parse_list_opts(opts) do
    search = find_opt(opts, "--search")
    online = "--online" in opts
    {search, online}
  end

  defp parse_ban_opts(opts) do
    reason = find_opt(opts, "--reason")
    duration_str = find_opt(opts, "--duration")
    duration = if duration_str, do: Duration.parse(duration_str), else: nil
    {reason, duration}
  end

  defp parse_reason([]), do: nil

  defp parse_reason(opts) do
    reason = find_opt(opts, "--reason")
    if reason, do: reason, else: Enum.join(opts, " ")
  end

  defp parse_duration_opt(opts) do
    case find_opt(opts, "--duration") do
      nil -> :permanent
      str -> Duration.parse(str)
    end
  end

  defp find_opt(opts, flag) do
    case Enum.find_index(opts, &(&1 == flag)) do
      nil -> nil
      idx -> Enum.at(opts, idx + 1)
    end
  end
end

defmodule RetroHexChat.Commands.Handlers.Admin.Channel do
  @moduledoc "Admin subcommands for channel management."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Queries

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["list" | opts], context) do
    search = find_opt(opts, "--search")
    AuditLogs.log(context.nickname, gettext("channel.list"))

    channels =
      case Registry.select(RetroHexChat.Channels.ChannelRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}]) do
        list -> list
      end

    filtered =
      if search do
        Enum.filter(channels, &String.contains?(&1, search))
      else
        channels
      end

    text =
      if filtered == [] do
        gettext("*** No active channels.")
      else
        header =
          gettext("*** Channel List (%{filtered_count}) ***", filtered_count: length(filtered))

        lines = Enum.map(filtered, &format_channel_entry/1)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute(["info", channel], context) do
    AuditLogs.log(context.nickname, gettext("channel.info"), {"channel", channel})

    case Server.get_state(channel) do
      {:ok, state} ->
        registered = Queries.find_registered_channel(channel)

        members =
          state.members
          |> Enum.map(fn {nick, role} -> gettext("%{nick} (%{role})", nick: nick, role: role) end)
          |> Enum.join(", ")

        reg_info =
          if registered do
            gettext("  Registered: yes (founder: %{founder_nickname})",
              founder_nickname: registered.founder_nickname
            )
          else
            gettext("  Registered: no")
          end

        topic = state.topic || gettext("(none)")

        text =
          gettext("*** Channel: %{channel}\n", channel: channel) <>
            gettext("  Topic: %{topic}\n", topic: topic) <>
            gettext("  Members (%{member_count}): %{members}\n",
              member_count: state.member_count,
              members: members
            ) <>
            gettext("  Modes: %{modes}\n", modes: state.modes) <>
            gettext("  Bans: %{state_bans_count}\n", state_bans_count: length(state.bans)) <>
            reg_info

        {:ok, :system, %{content: text}}

      {:error, :not_found} ->
        {:error, "Channel #{channel} not found"}
    end
  end

  def execute(["create", channel], context) do
    case Admin.create_channel(channel, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: gettext("*** %{message}", message: msg)}}
      {:error, msg} -> {:error, msg}
    end
  end

  def execute(["delete", channel], context) do
    {:ok, msg} = Admin.delete_channel(channel, context.nickname)
    {:ok, :system, %{content: gettext("*** %{message}", message: msg)}}
  end

  def execute(["purge", channel | opts], context) do
    from = find_opt(opts, "--from")
    purge_opts = if from, do: [from: strip_at(from)], else: []

    {:ok, msg} = Admin.purge_channel(channel, purge_opts, context.nickname)
    {:ok, :system, %{content: gettext("*** %{message}", message: msg)}}
  end

  def execute(["banlist", channel], _context) do
    case Server.get_state(channel) do
      {:ok, state} ->
        bans = state.bans

        text =
          if bans == [] do
            gettext("*** No bans in %{channel}.", channel: channel)
          else
            header =
              gettext("*** Ban List for %{channel} (%{bans_count}) ***",
                channel: channel,
                bans_count: length(bans)
              )

            lines = Enum.map(bans, &format_ban_entry/1)
            Enum.join([header | lines], "\n")
          end

        {:ok, :system, %{content: text}}

      {:error, :not_found} ->
        {:error, "Channel #{channel} not found"}
    end
  end

  def execute([], _context) do
    {:error, gettext("Usage: /admin channel <list|info|create|delete|purge|banlist>")}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown channel subcommand: #{subcmd}"}
  end

  defp format_channel_entry(name) do
    registered = Queries.find_registered_channel(name) != nil

    member_count =
      case Server.get_state(name) do
        {:ok, state} -> state.member_count
        _ -> 0
      end

    reg = if registered, do: " [registered]", else: ""

    gettext("  %{name} (%{member_count} members)%{reg}",
      name: name,
      member_count: member_count,
      reg: reg
    )
  end

  defp format_ban_entry(nick) do
    "  #{nick}"
  end

  defp strip_at("@" <> nick), do: nick
  defp strip_at(nick), do: nick

  defp find_opt(opts, flag) do
    case Enum.find_index(opts, &(&1 == flag)) do
      nil -> nil
      idx -> Enum.at(opts, idx + 1)
    end
  end
end

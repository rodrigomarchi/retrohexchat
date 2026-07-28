defmodule RetroHexChat.Commands.Handlers.Admin.Channel do
  @moduledoc "Admin subcommands for channel management."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Admin.Table
  alias RetroHexChat.Channels.Directory
  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.Queries

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["list" | opts], context) do
    search = find_opt(opts, "--search")
    AuditLogs.log(context.nickname, "channel.list")

    # The directory snapshot each channel publishes carries the member count, so
    # listing no longer costs one synchronous call per channel.
    snapshots = if search, do: Directory.search(search), else: Directory.all()

    text =
      if snapshots == [] do
        dgettext("admin", "*** No active channels.")
      else
        header =
          dgettext("admin", "*** Channel List (%{filtered_count}) ***",
            filtered_count: length(snapshots)
          )

        lines = Enum.map(snapshots, &format_channel_entry/1)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text, table: channel_table(snapshots)}}
  end

  def execute(["info", channel], context) do
    AuditLogs.log(context.nickname, "channel.info", {"channel", channel})

    case Server.get_state(channel) do
      {:ok, state} ->
        registered = Queries.find_registered_channel(channel)

        members =
          state.members
          |> Enum.map(fn {nick, role} ->
            dgettext("admin", "%{nick} (%{role})", nick: nick, role: role)
          end)
          |> Enum.join(", ")

        reg_info =
          if registered do
            dgettext("admin", "  Registered: yes (founder: %{founder_nickname})",
              founder_nickname: registered.founder_nickname
            )
          else
            dgettext("admin", "  Registered: no")
          end

        topic = state.topic || dgettext("admin", "(none)")

        text =
          dgettext("admin", "*** Channel: %{channel}\n", channel: channel) <>
            dgettext("admin", "  Topic: %{topic}\n", topic: topic) <>
            dgettext("admin", "  Members (%{member_count}): %{members}\n",
              member_count: state.member_count,
              members: members
            ) <>
            dgettext("admin", "  Modes: %{modes}\n", modes: state.modes) <>
            dgettext("admin", "  Bans: %{state_bans_count}\n",
              state_bans_count: length(state.bans)
            ) <>
            reg_info

        {:ok, :system, %{content: text}}

      {:error, :not_found} ->
        {:error, "Channel #{channel} not found"}
    end
  end

  def execute(["create", channel], context) do
    case Admin.create_channel(channel, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: dgettext("admin", "*** %{message}", message: msg)}}
      {:error, msg} -> {:error, msg}
    end
  end

  def execute(["delete", channel], context) do
    {:ok, msg} = Admin.delete_channel(channel, context.nickname)
    {:ok, :system, %{content: dgettext("admin", "*** %{message}", message: msg)}}
  end

  def execute(["purge", channel | opts], context) do
    from = find_opt(opts, "--from")
    purge_opts = if from, do: [from: strip_at(from)], else: []

    {:ok, msg} = Admin.purge_channel(channel, purge_opts, context.nickname)
    {:ok, :system, %{content: dgettext("admin", "*** %{message}", message: msg)}}
  end

  def execute(["banlist", channel], _context) do
    case Server.get_state(channel) do
      {:ok, state} ->
        bans = state.bans

        text =
          if bans == [] do
            dgettext("admin", "*** No bans in %{channel}.", channel: channel)
          else
            header =
              dgettext("admin", "*** Ban List for %{channel} (%{bans_count}) ***",
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
    {:error, dgettext("admin", "Usage: /admin channel <list|info|create|delete|purge|banlist>")}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown channel subcommand: #{subcmd}"}
  end

  defp format_channel_entry(snapshot) do
    reg = if registered?(snapshot.name), do: " [registered]", else: ""

    dgettext("admin", "  %{name} (%{member_count} members)%{reg}",
      name: snapshot.name,
      member_count: snapshot.member_count,
      reg: reg
    )
  end

  defp registered?(name), do: Queries.find_registered_channel(name) != nil

  defp channel_table(snapshots) do
    Table.from_list(
      [
        Table.column(:name, dgettext("admin", "Channel")),
        Table.column(:member_count, dgettext("admin", "Members")),
        Table.column(:registered, dgettext("admin", "Registered"))
      ],
      snapshots,
      fn snapshot ->
        %{
          id: snapshot.name,
          name: snapshot.name,
          member_count: snapshot.member_count,
          topic: snapshot.topic,
          registered: registered?(snapshot.name)
        }
      end
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

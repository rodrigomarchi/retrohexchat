defmodule RetroHexChat.Commands.Handlers.Admin.ChanServ do
  @moduledoc "Admin subcommands for ChanServ management."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.{ChanServ, Queries}

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["drop", channel], context) do
    case Admin.drop_channel(channel, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: dgettext("admin", "*** %{message}", message: msg)}}
      {:error, msg} -> {:error, dgettext("admin", "[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["info", channel], context) do
    AuditLogs.log(context.nickname, dgettext("admin", "cs.info"), {"channel", channel})

    case ChanServ.info(channel) do
      {:ok, info} ->
        access = Queries.list_access(channel)

        access_text =
          if access == [] do
            dgettext("admin", "  Access list: (empty)")
          else
            lines = Enum.map(access, &format_access_entry/1)
            dgettext("admin", "  Access list:\n") <> Enum.join(lines, "\n")
          end

        text =
          dgettext("admin", "*** [ChanServ] %{name}\n", name: info.name) <>
            dgettext("admin", "  Founder: %{founder}\n", founder: info.founder) <>
            dgettext("admin", "  Registered: %{registered_at}\n",
              registered_at: info.registered_at
            ) <>
            dgettext("admin", "  Topic: %{topic}\n", topic: info.topic) <>
            dgettext("admin", "  Modes: %{modes}\n", modes: info.modes) <>
            access_text

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, dgettext("admin", "[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["transfer", channel, nick], context) do
    nick = strip_at(nick)

    case Admin.transfer_channel(channel, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: dgettext("admin", "*** %{message}", message: msg)}}
      {:error, msg} -> {:error, dgettext("admin", "[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["access", channel], context) do
    AuditLogs.log(context.nickname, dgettext("admin", "cs.access"), {"channel", channel})
    access = Queries.list_access(channel)

    text =
      if access == [] do
        dgettext("admin", "*** Access list for %{channel}: (empty)", channel: channel)
      else
        header = dgettext("admin", "*** Access List for %{channel} ***", channel: channel)

        lines =
          Enum.map(access, fn e ->
            dgettext("admin", "  %{nickname} [%{level}] (added by %{added_by})",
              nickname: e.nickname,
              level: e.level,
              added_by: e.added_by
            )
          end)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute(["access", channel, "add", level, nick], context) do
    nick = strip_at(nick)

    case Admin.manage_channel_access(channel, :add, level, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: dgettext("admin", "*** %{message}", message: msg)}}
      {:error, msg} -> {:error, dgettext("admin", "[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["access", channel, "del", level, nick], context) do
    nick = strip_at(nick)

    case Admin.manage_channel_access(channel, :remove, level, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: dgettext("admin", "*** %{message}", message: msg)}}
      {:error, msg} -> {:error, dgettext("admin", "[ChanServ] %{message}", message: msg)}
    end
  end

  def execute([], _context) do
    {:error, dgettext("admin", "Usage: /admin cs <drop|info|transfer|access> [args]")}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown cs subcommand: #{subcmd}. Try: drop, info, transfer, access"}
  end

  defp format_access_entry(e) do
    dgettext("admin", "    %{nickname} [%{level}] (added by %{added_by})",
      nickname: e.nickname,
      level: e.level,
      added_by: e.added_by
    )
  end

  defp strip_at("@" <> nick), do: nick
  defp strip_at(nick), do: nick
end

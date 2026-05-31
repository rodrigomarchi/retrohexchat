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
      {:ok, msg} -> {:ok, :system, %{content: gettext("*** %{message}", message: msg)}}
      {:error, msg} -> {:error, gettext("[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["info", channel], context) do
    AuditLogs.log(context.nickname, gettext("cs.info"), {"channel", channel})

    case ChanServ.info(channel) do
      {:ok, info} ->
        access = Queries.list_access(channel)

        access_text =
          if access == [] do
            gettext("  Access list: (empty)")
          else
            lines = Enum.map(access, &format_access_entry/1)
            gettext("  Access list:\n") <> Enum.join(lines, "\n")
          end

        text =
          gettext("*** [ChanServ] %{name}\n", name: info.name) <>
            gettext("  Founder: %{founder}\n", founder: info.founder) <>
            gettext("  Registered: %{registered_at}\n", registered_at: info.registered_at) <>
            gettext("  Topic: %{topic}\n", topic: info.topic) <>
            gettext("  Modes: %{modes}\n", modes: info.modes) <>
            access_text

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, gettext("[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["transfer", channel, nick], context) do
    nick = strip_at(nick)

    case Admin.transfer_channel(channel, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: gettext("*** %{message}", message: msg)}}
      {:error, msg} -> {:error, gettext("[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["access", channel], context) do
    AuditLogs.log(context.nickname, gettext("cs.access"), {"channel", channel})
    access = Queries.list_access(channel)

    text =
      if access == [] do
        gettext("*** Access list for %{channel}: (empty)", channel: channel)
      else
        header = gettext("*** Access List for %{channel} ***", channel: channel)

        lines =
          Enum.map(access, fn e ->
            gettext("  %{nickname} [%{level}] (added by %{added_by})",
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
      {:ok, msg} -> {:ok, :system, %{content: gettext("*** %{message}", message: msg)}}
      {:error, msg} -> {:error, gettext("[ChanServ] %{message}", message: msg)}
    end
  end

  def execute(["access", channel, "del", level, nick], context) do
    nick = strip_at(nick)

    case Admin.manage_channel_access(channel, :remove, level, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: gettext("*** %{message}", message: msg)}}
      {:error, msg} -> {:error, gettext("[ChanServ] %{message}", message: msg)}
    end
  end

  def execute([], _context) do
    {:error, gettext("Usage: /admin cs <drop|info|transfer|access> [args]")}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown cs subcommand: #{subcmd}. Try: drop, info, transfer, access"}
  end

  defp format_access_entry(e) do
    gettext("    %{nickname} [%{level}] (added by %{added_by})",
      nickname: e.nickname,
      level: e.level,
      added_by: e.added_by
    )
  end

  defp strip_at("@" <> nick), do: nick
  defp strip_at(nick), do: nick
end

defmodule RetroHexChat.Commands.Handlers.Admin.ChanServ do
  @moduledoc "Admin subcommands for ChanServ management."

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.{ChanServ, Queries}

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["drop", channel], context) do
    case Admin.drop_channel(channel, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, "[ChanServ] #{msg}"}
    end
  end

  def execute(["info", channel], context) do
    AuditLogs.log(context.nickname, "cs.info", {"channel", channel})

    case ChanServ.info(channel) do
      {:ok, info} ->
        access = Queries.list_access(channel)

        access_text =
          if access == [] do
            "  Access list: (empty)"
          else
            lines = Enum.map(access, &format_access_entry/1)
            "  Access list:\n" <> Enum.join(lines, "\n")
          end

        text =
          "*** [ChanServ] #{info.name}\n" <>
            "  Founder: #{info.founder}\n" <>
            "  Registered: #{info.registered_at}\n" <>
            "  Topic: #{info.topic}\n" <>
            "  Modes: #{info.modes}\n" <>
            access_text

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, "[ChanServ] #{msg}"}
    end
  end

  def execute(["transfer", channel, nick], context) do
    nick = strip_at(nick)

    case Admin.transfer_channel(channel, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, "[ChanServ] #{msg}"}
    end
  end

  def execute(["access", channel], context) do
    AuditLogs.log(context.nickname, "cs.access", {"channel", channel})
    access = Queries.list_access(channel)

    text =
      if access == [] do
        "*** Access list for #{channel}: (empty)"
      else
        header = "*** Access List for #{channel} ***"

        lines =
          Enum.map(access, fn e ->
            "  #{e.nickname} [#{e.level}] (added by #{e.added_by})"
          end)

        Enum.join([header | lines], "\n")
      end

    {:ok, :system, %{content: text}}
  end

  def execute(["access", channel, "add", level, nick], context) do
    nick = strip_at(nick)

    case Admin.manage_channel_access(channel, :add, level, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, "[ChanServ] #{msg}"}
    end
  end

  def execute(["access", channel, "del", level, nick], context) do
    nick = strip_at(nick)

    case Admin.manage_channel_access(channel, :remove, level, nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, "[ChanServ] #{msg}"}
    end
  end

  def execute([], _context) do
    {:error, "Usage: /admin cs <drop|info|transfer|access> [args]"}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown cs subcommand: #{subcmd}. Try: drop, info, transfer, access"}
  end

  defp format_access_entry(e) do
    "    #{e.nickname} [#{e.level}] (added by #{e.added_by})"
  end

  defp strip_at("@" <> nick), do: nick
  defp strip_at(nick), do: nick
end

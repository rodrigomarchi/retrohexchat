defmodule RetroHexChat.Commands.Handlers.Admin.NickServ do
  @moduledoc "Admin subcommands for NickServ management."

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.AuditLogs
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.NickServ

  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(["drop", nick], context) do
    nick = strip_at(nick)

    case Admin.drop_nick(nick, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, "[NickServ] #{msg}"}
    end
  end

  def execute(["info", nick], context) do
    nick = strip_at(nick)
    AuditLogs.log(context.nickname, "ns.info", {"user", nick})

    case NickServ.info(nick) do
      {:ok, info} ->
        text =
          "*** [NickServ] #{nick}\n" <>
            "  Registered: #{info.registered_at}\n" <>
            "  Last seen: #{info.last_seen_at}\n" <>
            "  Identified: #{info.identified}"

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, "[NickServ] #{msg}"}
    end
  end

  def execute(["resetpass", nick, new_password], context) do
    nick = strip_at(nick)

    case Admin.reset_password(nick, new_password, context.nickname) do
      {:ok, msg} -> {:ok, :system, %{content: "*** #{msg}"}}
      {:error, msg} -> {:error, "[NickServ] #{msg}"}
    end
  end

  def execute([], _context) do
    {:error, "Usage: /admin ns <drop|info|resetpass> [args]"}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown ns subcommand: #{subcmd}. Try: drop, info, resetpass"}
  end

  defp strip_at("@" <> nick), do: nick
  defp strip_at(nick), do: nick
end

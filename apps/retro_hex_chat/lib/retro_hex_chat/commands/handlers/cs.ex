defmodule RetroHexChat.Commands.Handlers.Cs do
  @moduledoc "Handler for /cs (ChanServ commands)"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.ChanServ

  @access_levels ~w(sop aop vop)

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, "Usage: /cs <register|drop|info|sop|aop|vop|help> [args]"}
  end

  def execute(["register" | _], context) do
    call_register(context.active_channel, context.nickname, server(context))
  end

  def execute(["drop" | _], context) do
    call_drop(context.active_channel, context.nickname, server(context))
  end

  def execute(["info" | _], context) do
    call_info(context.active_channel, server(context))
  end

  def execute([level, "add", target | _], context) when level in @access_levels do
    call_manage_access(
      context.active_channel,
      :add,
      level,
      target,
      context.nickname,
      server(context)
    )
  end

  def execute([level, "del", target | _], context) when level in @access_levels do
    call_manage_access(
      context.active_channel,
      :remove,
      level,
      target,
      context.nickname,
      server(context)
    )
  end

  def execute([level, "list" | _], context) when level in @access_levels do
    call_list_access(context.active_channel, level, server(context))
  end

  def execute([level | _], _context) when level in @access_levels do
    {:error, "Usage: /cs #{level} <add|del|list> [nick]"}
  end

  def execute(["help" | _], _context) do
    {:ok, :ui_action, :show_help,
     %{
       commands: [
         "cs register",
         "cs drop",
         "cs info",
         "cs sop add/del/list",
         "cs aop add/del/list",
         "cs vop add/del/list"
       ]
     }}
  end

  def execute([subcmd | _], _context) do
    {:error, "Unknown ChanServ command: #{subcmd}. Try /cs help"}
  end

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "cs",
      syntax: "/cs <subcommand> [args]",
      description: "ChanServ commands for channel registration and access management.",
      examples: [
        "/cs register",
        "/cs drop",
        "/cs info",
        "/cs sop add nick",
        "/cs aop del nick",
        "/cs vop list"
      ]
    }
  end

  # ── Private helpers ─────────────────────────────────────────

  defp server(context), do: Map.get(context, :chan_serv, ChanServ)

  defp call_register(channel, founder, server) do
    case ChanServ.register(channel, founder, server) do
      {:ok, msg} -> {:ok, :system, %{content: "[ChanServ] #{msg}"}}
      {:error, msg} -> {:error, "[ChanServ] #{msg}"}
    end
  end

  defp call_drop(channel, nickname, server) do
    case ChanServ.drop(channel, nickname, server) do
      {:ok, msg} -> {:ok, :system, %{content: "[ChanServ] #{msg}"}}
      {:error, msg} -> {:error, "[ChanServ] #{msg}"}
    end
  end

  defp call_info(channel, server) do
    case ChanServ.info(channel, server) do
      {:ok, info} ->
        text =
          "[ChanServ] #{info.name}: founder=#{info.founder}, registered=#{info.registered_at}"

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, "[ChanServ] #{msg}"}
    end
  end

  defp call_manage_access(channel, action, level, target, requester, server) do
    case ChanServ.manage_access(channel, action, level, target, requester, server) do
      {:ok, msg} -> {:ok, :system, %{content: "[ChanServ] #{msg}"}}
      {:error, msg} -> {:error, "[ChanServ] #{msg}"}
    end
  end

  defp call_list_access(channel, _level, server) do
    case ChanServ.info(channel, server) do
      {:ok, _} ->
        {:ok, :system, %{content: "[ChanServ] Access list for #{channel}"}}

      {:error, msg} ->
        {:error, "[ChanServ] #{msg}"}
    end
  end
end

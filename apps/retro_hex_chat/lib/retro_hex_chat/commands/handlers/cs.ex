defmodule RetroHexChat.Commands.Handlers.Cs do
  @moduledoc "Handler for /cs (ChanServ commands)"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Channels.Server
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Services.{ChanServ, Queries}

  @access_levels ~w(sop aop vop)

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /cs <register|drop|info|sop|aop|vop|help> [args]")}
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
      syntax: dgettext("commands", "/cs <subcommand> [args]"),
      description:
        dgettext(
          "commands",
          "Manage channel registration and access lists through ChanServ.\nSubcommands: register, drop, info, sop/aop/vop add|del|list, help. Must be in a channel.\nAccess hierarchy: SOP (super-operator) > AOP (auto-operator) > VOP (auto-voice).\nRegister requires channel operator. Drop requires being the channel founder."
        ),
      examples: [
        dgettext("commands", "/cs register"),
        dgettext("commands", "/cs drop"),
        dgettext("commands", "/cs info"),
        dgettext("commands", "/cs sop add nick"),
        dgettext("commands", "/cs aop del nick"),
        dgettext("commands", "/cs vop list")
      ]
    }
  end

  # ── Private helpers ─────────────────────────────────────────

  defp server(context), do: Map.get(context, :chan_serv, ChanServ)

  defp call_register(channel, founder, server) do
    case ChanServ.register(channel, founder, server) do
      {:ok, msg} ->
        _ = Server.mark_registered(channel)
        {:ok, :system, %{content: dgettext("commands", "[ChanServ] %{message}", message: msg)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[ChanServ] %{message}", message: msg)}
    end
  end

  defp call_drop(channel, nickname, server) do
    case ChanServ.drop(channel, nickname, server) do
      {:ok, msg} ->
        {:ok, :system, %{content: dgettext("commands", "[ChanServ] %{message}", message: msg)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[ChanServ] %{message}", message: msg)}
    end
  end

  defp call_info(channel, server) do
    case ChanServ.info(channel, server) do
      {:ok, info} ->
        text =
          dgettext(
            "commands",
            "[ChanServ] %{name}: founder=%{founder}, registered=%{registered_at}",
            name: info.name,
            founder: info.founder,
            registered_at: info.registered_at
          )

        {:ok, :system, %{content: text}}

      {:error, msg} ->
        {:error, dgettext("commands", "[ChanServ] %{message}", message: msg)}
    end
  end

  defp call_manage_access(channel, action, level, target, requester, server) do
    case ChanServ.manage_access(channel, action, level, target, requester, server) do
      {:ok, msg} ->
        {:ok, :system, %{content: dgettext("commands", "[ChanServ] %{message}", message: msg)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[ChanServ] %{message}", message: msg)}
    end
  end

  defp call_list_access(channel, level, server) do
    case ChanServ.info(channel, server) do
      {:ok, _} ->
        {:ok, :system, %{content: format_access_list(channel, level)}}

      {:error, msg} ->
        {:error, dgettext("commands", "[ChanServ] %{message}", message: msg)}
    end
  end

  defp format_access_list(channel, level) do
    entries =
      channel
      |> Queries.list_access()
      |> Enum.filter(&(&1.level == level))

    [
      dgettext("commands", "[ChanServ] Access list for %{channel} (%{level})",
        channel: channel,
        level: level
      )
      | format_access_lines(entries)
    ]
    |> Enum.join("\n")
  end

  defp format_access_lines([]), do: [dgettext("commands", "  (empty)")]

  defp format_access_lines(entries) do
    Enum.map(entries, fn entry ->
      dgettext("commands", "  %{nickname} [%{level}] (added by %{added_by})",
        nickname: entry.nickname,
        level: entry.level,
        added_by: entry.added_by
      )
    end)
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "cs",
      syntax: dgettext("commands", "/cs <subcommand> [args]"),
      description:
        dgettext("commands", "Manage channel registration and access lists through ChanServ."),
      category: :advanced,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: true,
          type: :text,
          position: 0,
          description: dgettext("commands", "Subcommand: register, drop, info, sop, aop, vop")
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "Subcommand arguments")
        }
      ],
      examples: [
        dgettext("commands", "/cs register"),
        dgettext("commands", "/cs drop"),
        dgettext("commands", "/cs info"),
        dgettext("commands", "/cs sop add nick"),
        dgettext("commands", "/cs aop del nick"),
        dgettext("commands", "/cs vop list")
      ],
      subcommands: [
        %{name: "register", description: dgettext("commands", "Register the current channel")},
        %{name: "drop", description: dgettext("commands", "Drop channel registration")},
        %{name: "info", description: dgettext("commands", "View channel registration info")},
        %{name: "sop", description: dgettext("commands", "Manage super-operator access list")},
        %{name: "aop", description: dgettext("commands", "Manage auto-operator access list")},
        %{name: "vop", description: dgettext("commands", "Manage auto-voice access list")},
        %{name: "help", description: dgettext("commands", "Show ChanServ help")}
      ]
    }
  end
end

defmodule RetroHexChat.Commands.Handlers.Admin do
  @moduledoc "Handler for /admin — dispatches to subcommand modules."
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handlers.Admin, as: Sub

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error,
     gettext("Usage: /admin <server|user|channel|ns|cs|debug|log|turn|nuke> <subcommand> [args]")}
  end

  def execute(args, context) do
    if context.is_admin do
      dispatch(args, context)
    else
      {:error, gettext("You must be a server administrator to use this command")}
    end
  end

  defp dispatch(["server" | rest], context), do: Sub.Server.execute(rest, context)
  defp dispatch(["user" | rest], context), do: Sub.User.execute(rest, context)
  defp dispatch(["channel" | rest], context), do: Sub.Channel.execute(rest, context)
  defp dispatch(["ns" | rest], context), do: Sub.NickServ.execute(rest, context)
  defp dispatch(["cs" | rest], context), do: Sub.ChanServ.execute(rest, context)
  defp dispatch(["debug" | rest], context), do: Sub.Debug.execute(rest, context)
  defp dispatch(["log" | rest], context), do: Sub.Log.execute(rest, context)
  defp dispatch(["turn" | rest], context), do: Sub.Turn.execute(rest, context)
  defp dispatch(["nuke" | rest], context), do: Sub.Nuke.execute(rest, context)

  defp dispatch([subcmd | _], _context) do
    {:error,
     gettext(
       "Unknown admin subcommand: %{subcmd}. Try: server, user, channel, ns, cs, debug, log, turn, nuke",
       subcmd: subcmd
     )}
  end

  @impl true
  def help do
    %{
      name: "admin",
      syntax: gettext("/admin <subcommand> [args]"),
      description:
        gettext("Server administration commands. Requires admin privilege.\n") <>
          gettext("Subcommands: server, user, channel, ns, cs, debug, log, turn, nuke.\n") <>
          gettext("Type /admin <subcommand> for usage details."),
      examples: [
        gettext("/admin server info"),
        gettext("/admin user list"),
        gettext("/admin user ban @nick --reason Spam"),
        gettext("/admin channel delete #canal"),
        gettext("/admin ns drop @nick"),
        gettext("/admin cs transfer #canal @nick"),
        gettext("/admin debug memory"),
        gettext("/admin log --last 20"),
        gettext("/admin turn stats"),
        gettext("/admin nuke"),
        gettext("/admin nuke --confirm")
      ]
    }
  end

  @impl true
  def category, do: :advanced

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "admin",
      syntax: gettext("/admin <subcommand> [args]"),
      description: gettext("Server administration commands. Requires admin privilege."),
      category: :advanced,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: true,
          type: :text,
          position: 0,
          description: gettext("server, user, channel, ns, cs, debug, log, turn, or nuke")
        },
        %Parameter{
          name: "args",
          required: false,
          type: :text,
          position: 1,
          description: gettext("Subcommand arguments")
        }
      ],
      examples: [
        gettext("/admin server info"),
        gettext("/admin user list"),
        gettext("/admin user ban @nick"),
        gettext("/admin log"),
        gettext("/admin turn stats"),
        gettext("/admin nuke --confirm")
      ],
      subcommands: [
        %{name: "server", description: gettext("Server info and settings")},
        %{name: "user", description: gettext("User management (ban, kick, mute, rename, role)")},
        %{name: "channel", description: gettext("Channel management (create, delete, purge)")},
        %{name: "ns", description: gettext("NickServ admin (drop, info, resetpass)")},
        %{name: "cs", description: gettext("ChanServ admin (drop, info, transfer, access)")},
        %{name: "debug", description: gettext("Debug info (connections, processes, memory)")},
        %{name: "log", description: gettext("View audit log")},
        %{name: "turn", description: gettext("TURN server status and allocations")},
        %{
          name: "nuke",
          description: gettext("Factory reset — destroy all data except admin infrastructure")
        }
      ]
    }
  end
end

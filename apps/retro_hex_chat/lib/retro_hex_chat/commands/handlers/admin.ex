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
     dgettext(
       "commands",
       "Usage: /admin <server|user|channel|ns|cs|debug|log|turn|nuke> <subcommand> [args]"
     )}
  end

  def execute(args, context) do
    if context.is_admin do
      dispatch(args, context)
    else
      {:error, dgettext("commands", "You must be a server administrator to use this command")}
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
     dgettext(
       "commands",
       "Unknown admin subcommand: %{subcmd}. Try: server, user, channel, ns, cs, debug, log, turn, nuke",
       subcmd: subcmd
     )}
  end

  @impl true
  def help do
    %{
      name: "admin",
      syntax: dgettext("commands", "/admin <subcommand> [args]"),
      description:
        dgettext("commands", "Server administration commands. Requires admin privilege.\n") <>
          dgettext(
            "commands",
            "Subcommands: server, user, channel, ns, cs, debug, log, turn, nuke.\n"
          ) <>
          dgettext("commands", "Type /admin <subcommand> for usage details."),
      examples: [
        dgettext("commands", "/admin server info"),
        dgettext("commands", "/admin user list"),
        dgettext("commands", "/admin user ban @nick --reason Spam"),
        dgettext("commands", "/admin channel delete #canal"),
        dgettext("commands", "/admin ns drop @nick"),
        dgettext("commands", "/admin cs transfer #canal @nick"),
        dgettext("commands", "/admin debug memory"),
        dgettext("commands", "/admin log --last 20"),
        dgettext("commands", "/admin turn stats"),
        dgettext("commands", "/admin nuke"),
        dgettext("commands", "/admin nuke --confirm")
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
      syntax: dgettext("commands", "/admin <subcommand> [args]"),
      description:
        dgettext("commands", "Server administration commands. Requires admin privilege."),
      category: :advanced,
      parameters: [
        %Parameter{
          name: "subcommand",
          required: true,
          type: :text,
          position: 0,
          description:
            dgettext("commands", "server, user, channel, ns, cs, debug, log, turn, or nuke")
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
        dgettext("commands", "/admin server info"),
        dgettext("commands", "/admin user list"),
        dgettext("commands", "/admin user ban @nick"),
        dgettext("commands", "/admin log"),
        dgettext("commands", "/admin turn stats"),
        dgettext("commands", "/admin nuke --confirm")
      ],
      subcommands: [
        %{name: "server", description: dgettext("commands", "Server info and settings")},
        %{
          name: "user",
          description: dgettext("commands", "User management (ban, kick, mute, rename, role)")
        },
        %{
          name: "channel",
          description: dgettext("commands", "Channel management (create, delete, purge)")
        },
        %{
          name: "ns",
          description: dgettext("commands", "NickServ admin (drop, info, resetpass)")
        },
        %{
          name: "cs",
          description: dgettext("commands", "ChanServ admin (drop, info, transfer, access)")
        },
        %{
          name: "debug",
          description: dgettext("commands", "Debug info (connections, processes, memory)")
        },
        %{name: "log", description: dgettext("commands", "View audit log")},
        %{name: "turn", description: dgettext("commands", "TURN server status and allocations")},
        %{
          name: "nuke",
          description:
            dgettext("commands", "Factory reset — destroy all data except admin infrastructure")
        }
      ]
    }
  end
end

defmodule RetroHexChat.Commands.Handlers.Help do
  @moduledoc "Handler for /help [command]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Registry

  use RetroHexChat.Commands.Handler,
    name: "help",
    category: :basics,
    syntax: dgettext("commands", "/help [command]"),
    summary:
      dgettext(
        "commands",
        "View help for any command, or browse all available commands.\nWith no args: lists all commands. With a command name: shows detailed help.\nAlso accessible via Help Topics in the toolbar."
      ),
    description:
      dgettext(
        "commands",
        "View help for any command, or browse all available commands.\nWith no args: lists all commands. With a command name: shows detailed help.\nAlso accessible via Help Topics in the toolbar."
      ),
    examples: ["/help", dgettext("commands", "/help join")],
    parameters: [
      %Parameter{
        name: "command",
        required: false,
        type: :command,
        position: 0,
        description: dgettext("commands", "Command name to view detailed help")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    commands = Registry.list_commands()
    {:ok, :ui_action, :show_help, %{commands: commands}}
  end

  def execute([command_name | _rest], _context) do
    case Registry.lookup(command_name) do
      {:ok, handler} ->
        {:ok, :ui_action, :show_command_help, %{help: handler.help()}}

      {:error, :unknown_command} ->
        {:error, "Unknown command: #{command_name}"}
    end
  end
end

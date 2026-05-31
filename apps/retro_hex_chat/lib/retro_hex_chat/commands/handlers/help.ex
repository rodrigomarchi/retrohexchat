defmodule RetroHexChat.Commands.Handlers.Help do
  @moduledoc "Handler for /help [command]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Registry

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

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

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "help",
      syntax: gettext("/help [command]"),
      description:
        gettext(
          "View help for any command, or browse all available commands.\nWith no args: lists all commands. With a command name: shows detailed help.\nAlso accessible via Help Topics in the toolbar."
        ),
      examples: ["/help", gettext("/help join")]
    }
  end

  @impl true
  def category, do: :basics

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "help",
      syntax: gettext("/help [command]"),
      description:
        gettext(
          "View help for any command, or browse all available commands.\nWith no args: lists all commands. With a command name: shows detailed help.\nAlso accessible via Help Topics in the toolbar."
        ),
      category: :basics,
      parameters: [
        %Parameter{
          name: "command",
          required: false,
          type: :command,
          position: 0,
          description: gettext("Command name to view detailed help")
        }
      ],
      examples: ["/help", gettext("/help join")]
    }
  end
end

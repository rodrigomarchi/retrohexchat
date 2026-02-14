defmodule RetroHexChat.Commands.Handlers.Help do
  @moduledoc "Handler for /help [command]"
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
      syntax: "/help [command]",
      description: "Show available commands or help for a specific command.",
      examples: ["/help", "/help join"]
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
      syntax: "/help [command]",
      description: "Show available commands or help for a specific command.",
      category: :basics,
      parameters: [
        %Parameter{
          name: "command",
          required: false,
          type: :command,
          position: 0,
          description: "Comando para ver ajuda detalhada"
        }
      ],
      examples: ["/help", "/help join"]
    }
  end
end

defmodule RetroHexChat.Commands.Handlers.Away do
  @moduledoc "Handler for /away [message]"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :clear_away, %{}}
  end

  def execute(args, _context) do
    message = Enum.join(args, " ")
    {:ok, :ui_action, :set_away, %{message: message}}
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
      name: "away",
      syntax: "/away [message]",
      description: "Set or clear your away status.",
      examples: ["/away Gone to lunch", "/away"]
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
      command: "away",
      syntax: "/away [message]",
      description: "Set or clear your away status.",
      category: :basics,
      parameters: [
        %Parameter{
          name: "message",
          required: false,
          type: :text,
          position: 0,
          description: "Mensagem de ausência (vazio para voltar)"
        }
      ],
      examples: ["/away Gone to lunch", "/away"]
    }
  end
end

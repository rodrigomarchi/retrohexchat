defmodule RetroHexChat.Commands.Handlers.Away do
  @moduledoc "Handler for /away [message]"
  use Gettext, backend: RetroHexChat.Gettext
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
      syntax: gettext("/away [message]"),
      description:
        gettext(
          "Mark yourself as temporarily unavailable, with an optional message shown in /whois.\nWith a message: sets you as away. Without arguments: clears your away status and marks you as back."
        ),
      examples: [gettext("/away Gone to lunch"), "/away"]
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
      syntax: gettext("/away [message]"),
      description:
        gettext(
          "Mark yourself as temporarily unavailable, with an optional message shown in /whois."
        ),
      category: :basics,
      parameters: [
        %Parameter{
          name: "message",
          required: false,
          type: :text,
          position: 0,
          description: gettext("Away message (empty to return)")
        }
      ],
      examples: [gettext("/away Gone to lunch"), "/away"]
    }
  end
end

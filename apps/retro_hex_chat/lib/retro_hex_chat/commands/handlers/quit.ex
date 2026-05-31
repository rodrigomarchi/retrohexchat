defmodule RetroHexChat.Commands.Handlers.Quit do
  @moduledoc "Handler for /quit [message]"
  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :quit, nil}
  end

  def execute(args, _context) do
    reason = Enum.join(args, " ")
    {:ok, :quit, reason}
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
      name: "quit",
      syntax: gettext("/quit [message]"),
      description:
        gettext(
          "Disconnect from the server and return to the connect screen.\nOther users see your optional quit message. All channels are left and your session ends."
        ),
      examples: ["/quit", gettext("/quit Goodbye!")]
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
      command: "quit",
      syntax: gettext("/quit [message]"),
      description:
        gettext(
          "Disconnect from the server and return to the connect screen. Other users see your optional quit message."
        ),
      category: :basics,
      parameters: [
        %Parameter{
          name: "message",
          required: false,
          type: :text,
          position: 0,
          description: gettext("Quit message")
        }
      ],
      examples: ["/quit", gettext("/quit Goodbye!")]
    }
  end
end

defmodule RetroHexChat.Commands.Handlers.Quit do
  @moduledoc "Handler for /quit [message]"
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
      syntax: "/quit [message]",
      description: "Disconnect from the chat.",
      examples: ["/quit", "/quit Goodbye!"]
    }
  end
end

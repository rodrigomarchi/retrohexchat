defmodule RetroHexChat.Commands.Handlers.Clear do
  @moduledoc "Handler for /clear"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, _context) do
    {:ok, :ui_action, :clear_chat, %{}}
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
      name: "clear",
      syntax: "/clear",
      description: "Clear the chat window.",
      examples: ["/clear"]
    }
  end
end

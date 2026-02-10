defmodule RetroHexChat.Commands.Handlers.Query do
  @moduledoc "Handler for /query <nickname>"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /query <nickname>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /query <nickname>"}

  def execute([target | _rest], _context) do
    {:ok, :ui_action, :open_query, %{nickname: target}}
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
      name: "query",
      syntax: "/query <nickname>",
      description: "Open a private message window with a user.",
      examples: ["/query Nick"]
    }
  end
end

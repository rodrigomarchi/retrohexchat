defmodule RetroHexChat.Commands.Handlers.Msg do
  @moduledoc "Handler for /msg <nickname> <message>"
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, "Usage: /msg <nickname> <message>"}
  def validate(_), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, "Usage: /msg <nickname> <message>"}

  def execute([_target], _context),
    do: {:error, "No message specified. Usage: /msg <nickname> <message>"}

  def execute([target | rest], _context) do
    content = Enum.join(rest, " ")
    {:ok, :message, %{target: target, content: content}}
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
      name: "msg",
      syntax: "/msg <nickname> <message>",
      description: "Send a private message to a user.",
      examples: ["/msg Nick Hello there!", "/msg Nick How are you?"]
    }
  end

  @impl true
  def category, do: :user
end

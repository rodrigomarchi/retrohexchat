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
      description:
        "Send a private message to another user, opening a PM conversation tab.\nBoth nickname and message text are required.",
      examples: ["/msg Nick Hello there!", "/msg Nick How are you?"]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "msg",
      syntax: "/msg <nickname> <message>",
      description:
        "Send a private message to another user, opening a PM conversation tab.\nBoth nickname and message text are required.",
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: "Message recipient"
        },
        %Parameter{
          name: "message",
          required: true,
          type: :text,
          position: 1,
          description: "Message content"
        }
      ],
      examples: ["/msg Nick Hello there!", "/msg Nick How are you?"]
    }
  end
end

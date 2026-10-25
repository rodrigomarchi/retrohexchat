defmodule RetroHexChat.Commands.Handlers.Msg do
  @moduledoc "Handler for /msg <nickname> <message>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "msg",
    category: :user,
    usage: dgettext("commands", "Usage: /msg <nickname> <message>"),
    syntax: dgettext("commands", "/msg <nickname> <message>"),
    summary:
      dgettext(
        "commands",
        "Send a private message to another user, opening a PM conversation tab.\nBoth nickname and message text are required."
      ),
    description:
      dgettext(
        "commands",
        "Send a private message to another user, opening a PM conversation tab.\nBoth nickname and message text are required."
      ),
    examples: [
      dgettext("commands", "/msg Nick Hello there!"),
      dgettext("commands", "/msg Nick How are you?")
    ],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "Message recipient")),
      Parameter.required(:text, "message", dgettext("commands", "Message content"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context),
    do: {:error, dgettext("commands", "Usage: /msg <nickname> <message>")}

  def execute([_target], _context),
    do: {:error, dgettext("commands", "No message specified. Usage: /msg <nickname> <message>")}

  def execute([target | rest], _context) do
    content = Enum.join(rest, " ")
    {:ok, :message, %{target: target, content: content}}
  end
end

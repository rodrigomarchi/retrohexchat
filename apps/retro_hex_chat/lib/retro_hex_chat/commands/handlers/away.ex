defmodule RetroHexChat.Commands.Handlers.Away do
  @moduledoc "Handler for /away [message]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "away",
    category: :basics,
    syntax: dgettext("commands", "/away [message]"),
    summary:
      dgettext(
        "commands",
        "Mark yourself as temporarily unavailable, with an optional message shown in /whois."
      ),
    description:
      dgettext(
        "commands",
        "Mark yourself as temporarily unavailable, with an optional message shown in /whois.\nWith a message: sets you as away. Without arguments: clears your away status and marks you as back."
      ),
    examples: [dgettext("commands", "/away Gone to lunch"), "/away"],
    parameters: [
      Parameter.optional(:text, "message", dgettext("commands", "Away message (empty to return)"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :ui_action, :clear_away, %{}}
  end

  def execute(args, _context) do
    message = Enum.join(args, " ")
    {:ok, :ui_action, :set_away, %{message: message}}
  end
end

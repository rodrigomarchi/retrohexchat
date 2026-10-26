# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Quit do
  @moduledoc "Handler for /quit [message]"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "quit",
    category: :basics,
    syntax: dgettext("commands", "/quit [message]"),
    summary:
      dgettext(
        "commands",
        "Disconnect from the server and return to the connect screen. Other users see your optional quit message."
      ),
    description:
      dgettext(
        "commands",
        "Disconnect from the server and return to the connect screen.\nOther users see your optional quit message. All channels are left and your session ends."
      ),
    examples: ["/quit", dgettext("commands", "/quit Goodbye!")],
    parameters: [
      Parameter.optional(:text, "message", dgettext("commands", "Quit message"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:ok, :quit, nil}
  end

  def execute(args, _context) do
    reason = Enum.join(args, " ")
    {:ok, :quit, reason}
  end
end

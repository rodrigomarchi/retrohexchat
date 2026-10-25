defmodule RetroHexChat.Commands.Handlers.Notice do
  @moduledoc """
  Handler for the /notice command.
  Sends a notice to a user or channel without creating a PM window.
  """
  use Gettext, backend: RetroHexChat.Gettext
  alias RetroHexChat.Commands.CommandSyntax.Parameter

  use RetroHexChat.Commands.Handler,
    name: "notice",
    category: :user,
    usage: dgettext("commands", "Usage: /notice <target> <message>"),
    syntax: dgettext("commands", "/notice <target> <message>"),
    summary:
      dgettext(
        "commands",
        "Send a lightweight notice to a user or channel that doesn't open a PM window on their side."
      ),
    description:
      dgettext(
        "commands",
        "Send a notice to a user or channel without opening a PM window on their side.\nBoth target and message are required. Target can be a nickname or a #channel."
      ),
    examples: [
      dgettext("commands", "/notice Alice Check out #project"),
      dgettext("commands", "/notice #elixir Server maintenance in 30 minutes")
    ],
    parameters: [
      Parameter.required(
        :nick,
        "target",
        dgettext("commands", "Recipient (nickname or channel)")
      ),
      Parameter.required(:text, "message", dgettext("commands", "Notice content"))
    ]

  @impl true
  @spec execute([String.t()], RetroHexChat.Commands.Handler.context()) ::
          RetroHexChat.Commands.Handler.result()
  def execute([], _context),
    do: {:error, dgettext("commands", "Usage: /notice <target> <message>")}

  def execute([_target], _context),
    do: {:error, dgettext("commands", "No message specified. Usage: /notice <target> <message>")}

  def execute([target | rest], _context) do
    content = Enum.join(rest, " ")
    {:ok, :notice, %{target: target, content: content}}
  end
end

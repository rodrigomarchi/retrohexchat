defmodule RetroHexChat.Commands.Handlers.Me do
  @moduledoc "Handler for /me <action>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "me",
    category: :basics,
    usage: dgettext("commands", "Usage: /me <action>"),
    syntax: dgettext("commands", "/me <action>"),
    summary:
      dgettext(
        "commands",
        "Describe what you are doing, shown as '* YourNick does something'. It works in channels and in private chats.\nAction text is required."
      ),
    description:
      dgettext(
        "commands",
        "Describe what you are doing, shown as '* YourNick does something'. It works in channels and in private chats.\nAction text is required."
      ),
    examples: [dgettext("commands", "/me waves hello"), dgettext("commands", "/me is away")],
    parameters: [
      Parameter.required(:text, "action", dgettext("commands", "Action text"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /me <action>")}

  # An action belongs wherever the person is talking: a channel or the private chat open now.
  def execute(args, context) do
    if context.active_channel == nil and context[:active_pm] == nil do
      {:error, dgettext("commands", "You are not in any channel")}
    else
      content = Enum.join(args, " ")
      {:ok, :action, %{content: content}}
    end
  end
end

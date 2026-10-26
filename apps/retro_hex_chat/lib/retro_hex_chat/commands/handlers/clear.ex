defmodule RetroHexChat.Commands.Handlers.Clear do
  @moduledoc "Handler for /clear"
  use Gettext, backend: RetroHexChat.Gettext

  use RetroHexChat.Commands.Handler,
    name: "clear",
    category: :basics,
    syntax: "/clear",
    summary:
      dgettext(
        "commands",
        "Clear all messages from the current chat window, giving you a fresh screen. Cannot be undone."
      ),
    description:
      dgettext(
        "commands",
        "Clear all messages from the current chat window, giving you a fresh screen. Cannot be undone."
      ),
    examples: ["/clear"],
    execute: {:ui_action, :clear_chat}
end

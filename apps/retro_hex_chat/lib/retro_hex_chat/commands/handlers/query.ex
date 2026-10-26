# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Query do
  @moduledoc "Handler for /query <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  use RetroHexChat.Commands.Handler,
    name: "query",
    category: :user,
    usage: dgettext("commands", "Usage: /query <nickname>"),
    syntax: dgettext("commands", "/query <nickname>"),
    summary:
      dgettext(
        "commands",
        "Open a private message tab with a user without sending any message, unlike /msg."
      ),
    description:
      dgettext(
        "commands",
        "Open a private message tab with a user without sending any message, unlike /msg.\nNickname is required. If the PM tab already exists, switches to it."
      ),
    examples: [dgettext("commands", "/query Nick")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "Open a PM tab with this user"))
    ],
    execute: {:nick_action, :open_query, dgettext("commands", "Usage: /query <nickname>")}
end

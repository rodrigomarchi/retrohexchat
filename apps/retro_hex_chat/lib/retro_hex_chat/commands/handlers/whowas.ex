# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Whowas do
  @moduledoc "Handler for /whowas <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  use RetroHexChat.Commands.Handler,
    name: "whowas",
    category: :user,
    usage: dgettext("commands", "Usage: /whowas <nickname>"),
    syntax: dgettext("commands", "/whowas <nickname>"),
    summary: dgettext("commands", "Look up information about a user who recently disconnected."),
    description:
      dgettext(
        "commands",
        "Look up information about a user who recently disconnected.\nShows last seen time, channels, and quit message. Data cached for up to 1 hour.\nFor online users, use /whois instead."
      ),
    examples: [dgettext("commands", "/whowas SomeUser")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "Recently disconnected user"))
    ],
    execute: {:nick_action, :show_whowas_info, dgettext("commands", "Usage: /whowas <nickname>")}
end

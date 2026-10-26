# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Whois do
  @moduledoc "Handler for /whois <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  use RetroHexChat.Commands.Handler,
    name: "whois",
    category: :user,
    usage: dgettext("commands", "Usage: /whois <nickname>"),
    syntax: dgettext("commands", "/whois <nickname>"),
    summary: dgettext("commands", "Look up detailed information about an online user."),
    description:
      dgettext(
        "commands",
        "Look up detailed information about an online user.\nShows: nickname, channels (shared channels highlighted), idle time, away status, bio, and registration status.\nUser must be online. For offline users, use /whowas."
      ),
    examples: [dgettext("commands", "/whois SomeUser")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to look up"))
    ],
    execute: {:nick_action, :show_whois_info, dgettext("commands", "Usage: /whois <nickname>")}
end

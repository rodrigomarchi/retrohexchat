defmodule RetroHexChat.Commands.Handlers.Ban do
  @moduledoc "Handler for /ban <nickname> [reason]"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  use RetroHexChat.Commands.Handler,
    name: "ban",
    category: :channel,
    syntax: dgettext("commands", "/ban <nickname> [reason]"),
    summary:
      dgettext(
        "commands",
        "Permanently block a user from the channel. The ban persists until removed with /mode -b."
      ),
    description:
      dgettext(
        "commands",
        "Permanently block a user from the channel. The ban persists until removed with /mode -b.\nRequires: channel operator. Must be in a channel."
      ),
    examples: [
      dgettext("commands", "/ban troll"),
      dgettext("commands", "/ban troll Repeated violations")
    ],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to ban")),
      Parameter.optional(:text, "reason", dgettext("commands", "Reason for the ban"))
    ],
    execute:
      {:channel_target, dgettext("commands", "Usage: /ban <nickname> [reason]"),
       &require_operator(
         &1,
         &2,
         dgettext("commands", "You must be a channel operator to ban users")
       ), &{:ok, :ui_action, :ban_user, %{channel: &1, target: &2, reason: &3}}}
end

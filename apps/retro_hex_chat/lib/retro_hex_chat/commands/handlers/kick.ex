defmodule RetroHexChat.Commands.Handlers.Kick do
  @moduledoc "Handler for /kick <nickname> [reason]"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  use RetroHexChat.Commands.Handler,
    name: "kick",
    category: :channel,
    syntax: dgettext("commands", "/kick <nickname> [reason]"),
    summary:
      dgettext(
        "commands",
        "Remove a user from the channel with an optional reason. They can rejoin unless also banned.\nRequires: channel operator or half-operator. Must be in a channel."
      ),
    description:
      dgettext(
        "commands",
        "Remove a user from the channel with an optional reason. They can rejoin unless also banned.\nRequires: channel operator or half-operator. Must be in a channel."
      ),
    examples: [
      dgettext("commands", "/kick troll"),
      dgettext("commands", "/kick troll Spamming the channel")
    ],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to kick")),
      Parameter.optional(:text, "reason", dgettext("commands", "Reason for the kick"))
    ],
    execute:
      {:channel_target, dgettext("commands", "Usage: /kick <nickname> [reason]"),
       &require_half_op_or_above(
         &1,
         &2,
         dgettext("commands", "You must be a channel operator to kick users")
       ), &{:ok, :ui_action, :kick_user, %{channel: &1, target: &2, reason: &3}}}
end

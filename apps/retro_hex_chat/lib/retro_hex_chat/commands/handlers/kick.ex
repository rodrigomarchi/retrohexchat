defmodule RetroHexChat.Commands.Handlers.Kick do
  @moduledoc "Handler for /kick <nickname> [reason]"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

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
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to kick")
      },
      %Parameter{
        name: "reason",
        required: false,
        type: :text,
        position: 1,
        description: dgettext("commands", "Reason for the kick")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    on_channel_target(
      args,
      context,
      dgettext("commands", "Usage: /kick <nickname> [reason]"),
      &require_half_op_or_above(
        &1,
        &2,
        dgettext("commands", "You must be a channel operator to kick users")
      ),
      &{:ok, :ui_action, :kick_user, %{channel: &1, target: &2, reason: &3}}
    )
  end
end

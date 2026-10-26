# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Unmute do
  @moduledoc "Handler for /unmute <nickname> — remove channel-level mute."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "unmute",
    category: :channel,
    syntax: dgettext("commands", "/unmute <nickname>"),
    summary: dgettext("commands", "Remove a channel-level mute from a user."),
    description:
      dgettext(
        "commands",
        "Remove a channel-level mute from a user.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/unmute alice")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to unmute"))
    ],
    execute:
      {:channel_target, dgettext("commands", "Usage: /unmute <nickname>"), &require_operator/2,
       &{:ok, :ui_action, :channel_unmute_user, %{channel: &1, target: &2}}}
end

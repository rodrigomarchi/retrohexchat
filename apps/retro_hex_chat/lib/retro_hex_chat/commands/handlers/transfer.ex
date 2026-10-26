# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Transfer do
  @moduledoc "Handler for /transfer <nickname> — transfer channel ownership."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "transfer",
    category: :channel,
    syntax: dgettext("commands", "/transfer <nickname>"),
    summary: dgettext("commands", "Transfer channel ownership to another user."),
    description:
      dgettext(
        "commands",
        "Transfer channel ownership to another user.\nThe new owner gets +q (owner) and you are demoted to operator.\nRequires: channel owner."
      ),
    examples: [dgettext("commands", "/transfer alice")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "New owner"))
    ],
    execute:
      {:channel_target, dgettext("commands", "Usage: /transfer <nickname>"), &require_owner/2,
       &{:ok, :ui_action, :transfer_ownership, %{channel: &1, target: &2}}}
end

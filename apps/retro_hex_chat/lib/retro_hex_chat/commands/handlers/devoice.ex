# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Devoice do
  @moduledoc "Handler for /devoice <nickname> — remove voice status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "devoice",
    category: :channel,
    syntax: dgettext("commands", "/devoice <nickname>"),
    summary: dgettext("commands", "Remove voice status from a user."),
    description:
      dgettext(
        "commands",
        "Remove voice status from a user. Shortcut for /mode -v <nickname>.\nRequires: half-operator, operator, or owner."
      ),
    examples: [dgettext("commands", "/devoice alice")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to remove voice from"))
    ],
    execute:
      {:channel_target, dgettext("commands", "Usage: /devoice <nickname>"),
       &require_half_op_or_above/2,
       &{:ok, :ui_action, :set_mode, %{channel: &1, mode_string: "-v", params: [&2]}}}
end

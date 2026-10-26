# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Op do
  @moduledoc "Handler for /op <nickname> — give channel operator status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "op",
    category: :channel,
    syntax: dgettext("commands", "/op <nickname>"),
    summary: dgettext("commands", "Give channel operator status to a user."),
    description:
      dgettext(
        "commands",
        "Give channel operator status to a user. Shortcut for /mode +o <nickname>.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/op alice")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to give operator status"))
    ],
    execute:
      {:channel_target, dgettext("commands", "Usage: /op <nickname>"), &require_operator/2,
       &{:ok, :ui_action, :set_mode, %{channel: &1, mode_string: "+o", params: [&2]}}}
end

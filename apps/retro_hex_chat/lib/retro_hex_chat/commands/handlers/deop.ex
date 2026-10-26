# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Deop do
  @moduledoc "Handler for /deop <nickname> — remove channel operator status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "deop",
    category: :channel,
    syntax: dgettext("commands", "/deop <nickname>"),
    summary: dgettext("commands", "Remove channel operator status from a user."),
    description:
      dgettext(
        "commands",
        "Remove channel operator status from a user. Shortcut for /mode -o <nickname>.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/deop alice")],
    parameters: [
      Parameter.required(
        :nick,
        "nickname",
        dgettext("commands", "User to remove operator status from")
      )
    ],
    execute:
      {:channel_target, dgettext("commands", "Usage: /deop <nickname>"), &require_operator/2,
       &{:ok, :ui_action, :set_mode, %{channel: &1, mode_string: "-o", params: [&2]}}}
end

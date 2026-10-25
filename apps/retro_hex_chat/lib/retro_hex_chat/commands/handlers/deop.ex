defmodule RetroHexChat.Commands.Handlers.Deop do
  @moduledoc "Handler for /deop <nickname> — remove channel operator status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

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
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    on_channel_target(
      args,
      context,
      dgettext("commands", "Usage: /deop <nickname>"),
      &require_operator/2,
      &{:ok, :ui_action, :set_mode, %{channel: &1, mode_string: "-o", params: [&2]}}
    )
  end
end

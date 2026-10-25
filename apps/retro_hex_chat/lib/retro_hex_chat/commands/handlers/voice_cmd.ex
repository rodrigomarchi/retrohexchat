defmodule RetroHexChat.Commands.Handlers.VoiceCmd do
  @moduledoc "Handler for /voice <nickname> — give voice status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "voice",
    category: :channel,
    syntax: dgettext("commands", "/voice <nickname>"),
    summary: dgettext("commands", "Give voice status to a user."),
    description:
      dgettext(
        "commands",
        "Give voice status to a user. Shortcut for /mode +v <nickname>.\nRequires: half-operator, operator, or owner."
      ),
    examples: [dgettext("commands", "/voice alice")],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "User to give voice"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    on_channel_target(
      args,
      context,
      dgettext("commands", "Usage: /voice <nickname>"),
      &require_half_op_or_above/2,
      &{:ok, :ui_action, :set_mode, %{channel: &1, mode_string: "+v", params: [&2]}}
    )
  end
end

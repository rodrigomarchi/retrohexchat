defmodule RetroHexChat.Commands.Handlers.Devoice do
  @moduledoc "Handler for /devoice <nickname> — remove voice status."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

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
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    on_channel_target(
      args,
      context,
      dgettext("commands", "Usage: /devoice <nickname>"),
      &require_half_op_or_above/2,
      &{:ok, :ui_action, :set_mode, %{channel: &1, mode_string: "-v", params: [&2]}}
    )
  end
end

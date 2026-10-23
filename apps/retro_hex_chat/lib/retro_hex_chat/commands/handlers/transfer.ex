defmodule RetroHexChat.Commands.Handlers.Transfer do
  @moduledoc "Handler for /transfer <nickname> — transfer channel ownership."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

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
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "New owner")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    on_channel_target(
      args,
      context,
      dgettext("commands", "Usage: /transfer <nickname>"),
      &require_owner/2,
      &{:ok, :ui_action, :transfer_ownership, %{channel: &1, target: &2}}
    )
  end
end

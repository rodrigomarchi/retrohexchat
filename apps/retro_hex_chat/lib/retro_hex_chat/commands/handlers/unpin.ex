defmodule RetroHexChat.Commands.Handlers.Unpin do
  @moduledoc "Handler for /unpin <message id>"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards, only: [on_channel_message: 4]

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "unpin",
    category: :channel,
    syntax: dgettext("commands", "/unpin <message id>"),
    summary: dgettext("commands", "Stop keeping a message in view."),
    description:
      dgettext(
        "commands",
        "Stop keeping a message in view. The message itself stays where it is — only the pin goes.\nOperators only."
      ),
    examples: ["/unpin 1284"],
    parameters: [
      %Parameter{
        name: "message id",
        required: true,
        type: :text,
        position: 0,
        description: dgettext("commands", "Id of the message to stop keeping")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    on_channel_message(
      args,
      context,
      dgettext(
        "commands",
        "Which message? Use /unpin <id>, or unpin it from the Pinned window."
      ),
      &{:ok, :ui_action, :unpin_message, %{channel: &1, message_id: &2}}
    )
  end
end

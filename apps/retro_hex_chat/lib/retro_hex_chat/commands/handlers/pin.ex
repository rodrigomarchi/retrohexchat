defmodule RetroHexChat.Commands.Handlers.Pin do
  @moduledoc "Handler for /pin <message id>"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards, only: [on_channel_message: 4]

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "pin",
    category: :channel,
    syntax: dgettext("commands", "/pin <message id>"),
    summary: dgettext("commands", "Keep a message in view for the whole channel."),
    description:
      dgettext(
        "commands",
        "Keep a message in view for the whole channel — the rules, a link, what was agreed.\nPinned messages are listed in the Pinned window and stay findable after they scroll away.\nOperators only. A channel keeps up to 50."
      ),
    examples: ["/pin 1284"],
    parameters: [
      Parameter.required(:text, "message id", dgettext("commands", "Id of the message to keep"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  # The id rather than "the last message": the command is for keeping a line
  # somebody has scrolled back to find, and that line is rarely the newest one.
  def execute(args, context) do
    on_channel_message(
      args,
      context,
      dgettext("commands", "Which message? Use /pin <id>, or pin it from its right-click menu."),
      &{:ok, :ui_action, :pin_message, %{channel: &1, message_id: &2}}
    )
  end
end

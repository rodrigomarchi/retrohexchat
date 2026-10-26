# ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
defmodule RetroHexChat.Commands.Handlers.Unpin do
  @moduledoc "Handler for /unpin <message id>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter

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
      Parameter.required(
        :text,
        "message id",
        dgettext("commands", "Id of the message to stop keeping")
      )
    ],
    execute:
      {:channel_message,
       dgettext(
         "commands",
         "Which message? Use /unpin <id>, or unpin it from the Pinned window."
       ), &{:ok, :ui_action, :unpin_message, %{channel: &1, message_id: &2}}}
end

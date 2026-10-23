defmodule RetroHexChat.Commands.Handlers.Unpin do
  @moduledoc "Handler for /unpin <message id>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Args

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
  def execute([], _context) do
    {:error,
     dgettext(
       "commands",
       "Which message? Use /unpin <id>, or unpin it from the Pinned window."
     )}
  end

  def execute([raw_id | _rest], context) do
    case context.active_channel do
      nil ->
        {:error, dgettext("commands", "You are not in any channel")}

      channel ->
        with {:ok, id} <-
               Args.positive_id(raw_id, dgettext("commands", "That is not a message id")) do
          {:ok, :ui_action, :unpin_message, %{channel: channel, message_id: id}}
        end
    end
  end
end

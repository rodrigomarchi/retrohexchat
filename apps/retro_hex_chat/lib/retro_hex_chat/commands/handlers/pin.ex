defmodule RetroHexChat.Commands.Handlers.Pin do
  @moduledoc "Handler for /pin <message id>"
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Args

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
      %Parameter{
        name: "message id",
        required: true,
        type: :text,
        position: 0,
        description: dgettext("commands", "Id of the message to keep")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  # The id rather than "the last message": the command is for keeping a line
  # somebody has scrolled back to find, and that line is rarely the newest one.
  def execute([], _context) do
    {:error,
     dgettext("commands", "Which message? Use /pin <id>, or pin it from its right-click menu.")}
  end

  def execute([raw_id | _rest], context) do
    case context.active_channel do
      nil ->
        {:error, dgettext("commands", "You are not in any channel")}

      channel ->
        with {:ok, id} <-
               Args.positive_id(raw_id, dgettext("commands", "That is not a message id")) do
          {:ok, :ui_action, :pin_message, %{channel: channel, message_id: id}}
        end
    end
  end
end

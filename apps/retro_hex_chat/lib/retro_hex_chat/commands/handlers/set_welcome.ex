defmodule RetroHexChat.Commands.Handlers.SetWelcome do
  @moduledoc "Handler for /setwelcome <message> — operator sets channel welcome."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Guards

  # ex_dna:disable-for-next-line a command's declaration: literal gettext texts, one module per command
  use RetroHexChat.Commands.Handler,
    name: "setwelcome",
    category: :advanced,
    syntax: dgettext("commands", "/setwelcome <message>"),
    summary:
      dgettext(
        "commands",
        "Set a message shown once to each user when they join the current channel."
      ),
    description:
      dgettext(
        "commands",
        "Set a message shown once to each user when they join the current channel.\nRequires: channel operator. Must be in a channel.\nWith no args: clears the welcome message (same as /clearwelcome)."
      ),
    examples: [dgettext("commands", "/setwelcome Welcome to our channel!")],
    parameters: [
      Parameter.required(:text, "message", dgettext("commands", "Channel welcome message"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    with {:ok, channel} <- Guards.require_channel(context),
         :ok <- Guards.require_operator(context, channel) do
      case args do
        [] -> {:ok, :ui_action, :clear_welcome, %{channel: channel}}
        _ -> {:ok, :ui_action, :set_welcome, %{channel: channel, message: Enum.join(args, " ")}}
      end
    end
  end
end

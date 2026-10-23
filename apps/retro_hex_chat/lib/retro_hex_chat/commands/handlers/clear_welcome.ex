defmodule RetroHexChat.Commands.Handlers.ClearWelcome do
  @moduledoc "Handler for /clearwelcome — operator clears channel welcome."
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Guards

  use RetroHexChat.Commands.Handler,
    name: "clearwelcome",
    category: :advanced,
    syntax: "/clearwelcome",
    summary:
      dgettext(
        "commands",
        "Remove the welcome message from the current channel so new joiners won't see one."
      ),
    description:
      dgettext(
        "commands",
        "Remove the welcome message from the current channel so new joiners won't see one.\nRequires: channel operator. Must be in a channel."
      ),
    examples: ["/clearwelcome"]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(_args, context) do
    with {:ok, channel} <- Guards.require_channel(context),
         :ok <- Guards.require_operator(context, channel) do
      {:ok, :ui_action, :clear_welcome, %{channel: channel}}
    end
  end
end

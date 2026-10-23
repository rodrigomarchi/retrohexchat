defmodule RetroHexChat.Commands.Handlers.Unban do
  @moduledoc "Handler for /unban <nickname>"
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "unban",
    category: :channel,
    syntax: dgettext("commands", "/unban <nickname>"),
    summary:
      dgettext("commands", "Remove a ban from a user, allowing them to rejoin the channel."),
    description:
      dgettext(
        "commands",
        "Remove a ban from a user, allowing them to rejoin the channel.\nRequires: channel operator. Must be in a channel."
      ),
    examples: [dgettext("commands", "/unban user123")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to unban")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context) do
    {:error, dgettext("commands", "Usage: /unban <nickname>")}
  end

  def execute([target | _rest], context) do
    denied = dgettext("commands", "You must be a channel operator to unban users")

    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel, denied) do
      {:ok, :ui_action, :unban_user, %{channel: channel, target: target}}
    end
  end
end

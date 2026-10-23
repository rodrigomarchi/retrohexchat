defmodule RetroHexChat.Commands.Handlers.Unmute do
  @moduledoc "Handler for /unmute <nickname> — remove channel-level mute."
  use Gettext, backend: RetroHexChat.Gettext

  import RetroHexChat.Commands.Handler.Guards

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler

  use RetroHexChat.Commands.Handler,
    name: "unmute",
    category: :channel,
    syntax: dgettext("commands", "/unmute <nickname>"),
    summary: dgettext("commands", "Remove a channel-level mute from a user."),
    description:
      dgettext(
        "commands",
        "Remove a channel-level mute from a user.\nRequires: channel operator or owner."
      ),
    examples: [dgettext("commands", "/unmute alice")],
    parameters: [
      %Parameter{
        name: "nickname",
        required: true,
        type: :nick,
        position: 0,
        description: dgettext("commands", "User to unmute")
      }
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, dgettext("commands", "Usage: /unmute <nickname>")}

  def execute([nick | _], context) do
    with {:ok, channel} <- require_channel(context),
         :ok <- require_operator(context, channel) do
      {:ok, :ui_action, :channel_unmute_user, %{channel: channel, target: nick}}
    end
  end
end

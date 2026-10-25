defmodule RetroHexChat.Commands.Handlers.Challenge do
  @moduledoc """
  Handler for /challenge <nickname> [mode] — invite one person to play the
  channel's game.

  It is `/p2p` with the game already chosen: the same invite card in the same
  private conversation, under the same rules about who may invite whom. The
  session it opens proposes the game as soon as both are connected.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Guards
  alias RetroHexChat.Commands.Handlers.Lobby

  use RetroHexChat.Commands.Handler,
    name: "challenge",
    category: :user,
    usage: usage(),
    syntax: dgettext("commands", "/challenge <nickname> [mode]"),
    summary: dgettext("commands", "Invite someone to play the channel's game over a P2P session.
Requires: both users must be registered and identified (/ns identify)."),
    description:
      dgettext(
        "commands",
        "Invite someone to play the channel's game. Run it in a game's channel: they get a P2P invite in your private conversation, and the game starts once you are both in.\nName a mode to play it instead of the standard game.\nRequires: both users must be registered and identified (/ns identify)."
      ),
    examples: [
      dgettext("commands", "/challenge mario"),
      dgettext("commands", "/challenge mario quick")
    ],
    parameters: [
      Parameter.required(:nick, "nickname", dgettext("commands", "Who to play")),
      Parameter.optional(:text, "mode", dgettext("commands", "A mode of the game, like blitz"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute([], _context), do: {:error, usage()}

  def execute([target | mode], context) do
    with {:ok, %{game_id: game_id}} <- Guards.require_game_channel(context, mode),
         {:ok, :ui_action, :lobby_invite, invite} <- Lobby.execute([target], context) do
      {:ok, :ui_action, :lobby_invite, Map.put(invite, :game_id, game_id)}
    end
  end

  defp usage, do: dgettext("commands", "Usage: /challenge <nickname> [mode]")
end

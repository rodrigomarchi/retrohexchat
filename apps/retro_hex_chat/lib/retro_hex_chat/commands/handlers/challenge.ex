defmodule RetroHexChat.Commands.Handlers.Challenge do
  @moduledoc """
  Handler for /challenge <nickname> [mode] — invite one person to play the
  channel's game.

  It is `/p2p` with the game already chosen: the same invite card in the same
  private conversation, under the same rules about who may invite whom. The
  session it opens proposes the game as soon as both are connected.
  """

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Guards
  alias RetroHexChat.Commands.Handlers.Lobby

  @impl true
  @spec validate(String.t()) :: :ok | {:error, String.t()}
  def validate(""), do: {:error, usage()}
  def validate(_raw_args), do: :ok

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

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "challenge",
      syntax: dgettext("commands", "/challenge <nickname> [mode]"),
      description:
        dgettext(
          "commands",
          "Invite someone to play the channel's game. Run it in a game's channel: they get a P2P invite in your private conversation, and the game starts once you are both in.\nName a mode to play it instead of the standard game.\nRequires: both users must be registered and identified (/ns identify)."
        ),
      examples: [
        dgettext("commands", "/challenge mario"),
        dgettext("commands", "/challenge mario quick")
      ]
    }
  end

  @impl true
  def category, do: :user

  @impl true
  @spec syntax_definition() :: RetroHexChat.Commands.CommandSyntax.t()
  def syntax_definition do
    alias RetroHexChat.Commands.CommandSyntax
    alias RetroHexChat.Commands.CommandSyntax.Parameter

    %CommandSyntax{
      command: "challenge",
      syntax: dgettext("commands", "/challenge <nickname> [mode]"),
      description:
        dgettext("commands", "Invite someone to play the channel's game over a P2P session.
Requires: both users must be registered and identified (/ns identify)."),
      category: :user,
      parameters: [
        %Parameter{
          name: "nickname",
          required: true,
          type: :nick,
          position: 0,
          description: dgettext("commands", "Who to play")
        },
        %Parameter{
          name: "mode",
          required: false,
          type: :text,
          position: 1,
          description: dgettext("commands", "A mode of the game, like blitz")
        }
      ],
      examples: [
        dgettext("commands", "/challenge mario"),
        dgettext("commands", "/challenge mario quick")
      ]
    }
  end
end

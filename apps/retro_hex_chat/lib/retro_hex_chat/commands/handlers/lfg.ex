defmodule RetroHexChat.Commands.Handlers.Lfg do
  @moduledoc """
  Handler for /lfg [mode] — look for someone to play the channel's game with.

  Run in a game's channel, it opens a match with one empty seat and puts its
  card in the channel: whoever presses Join first plays. The match is the same
  open lobby a match link has always been; the channel is simply where the
  link is posted.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Commands.CommandSyntax.Parameter
  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Guards

  use RetroHexChat.Commands.Handler,
    name: "lfg",
    category: :user,
    syntax: dgettext("commands", "/lfg [mode]"),
    summary:
      dgettext(
        "commands",
        "Look for someone to play the channel's game with: a card with one open seat appears in the channel.
Requires: a registered, identified nickname."
      ),
    description:
      dgettext(
        "commands",
        "Look for someone to play the channel's game with. Run it in a game's channel: a card with one open seat appears in the channel, and whoever presses Join first plays you.\nName a mode to play it instead of the standard game.\nRequires: a registered, identified nickname."
      ),
    examples: [dgettext("commands", "/lfg"), dgettext("commands", "/lfg blitz")],
    parameters: [
      Parameter.optional(:text, "mode", dgettext("commands", "A mode of the game, like blitz"))
    ]

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    with :ok <-
           Guards.require_identified(
             context,
             dgettext("commands", "You must be identified to look for a match.")
           ),
         {:ok, %{channel: channel, game_id: game_id}} <-
           Guards.require_game_channel(context, args) do
      {:ok, :ui_action, :game_lfg, %{channel: channel, game_id: game_id}}
    end
  end
end

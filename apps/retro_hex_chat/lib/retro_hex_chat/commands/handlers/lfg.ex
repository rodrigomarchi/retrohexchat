defmodule RetroHexChat.Commands.Handlers.Lfg do
  @moduledoc """
  Handler for /lfg [mode] — look for someone to play the channel's game with.

  Run in a game's channel, it opens a match with one empty seat and puts its
  card in the channel: whoever presses Join first plays. The match is the same
  open lobby a match link has always been; the channel is simply where the
  link is posted.
  """

  use Gettext, backend: RetroHexChat.Gettext
  @behaviour RetroHexChat.Commands.Handler

  alias RetroHexChat.Commands.Handler
  alias RetroHexChat.Commands.Handler.Guards

  @impl true
  @spec validate(String.t()) :: :ok
  def validate(_raw_args), do: :ok

  @impl true
  @spec execute([String.t()], Handler.context()) :: Handler.result()
  def execute(args, context) do
    with :ok <- require_identified(context),
         {:ok, %{channel: channel, game_id: game_id}} <-
           Guards.require_game_channel(context, args) do
      {:ok, :ui_action, :game_lfg, %{channel: channel, game_id: game_id}}
    end
  end

  defp require_identified(%{identified: true}), do: :ok

  defp require_identified(_context),
    do: {:error, dgettext("commands", "You must be identified to look for a match.")}

  @impl true
  @spec help() :: %{
          name: String.t(),
          syntax: String.t(),
          description: String.t(),
          examples: [String.t()]
        }
  def help do
    %{
      name: "lfg",
      syntax: dgettext("commands", "/lfg [mode]"),
      description:
        dgettext(
          "commands",
          "Look for someone to play the channel's game with. Run it in a game's channel: a card with one open seat appears in the channel, and whoever presses Join first plays you.\nName a mode to play it instead of the standard game.\nRequires: a registered, identified nickname."
        ),
      examples: [dgettext("commands", "/lfg"), dgettext("commands", "/lfg blitz")]
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
      command: "lfg",
      syntax: dgettext("commands", "/lfg [mode]"),
      description:
        dgettext(
          "commands",
          "Look for someone to play the channel's game with: a card with one open seat appears in the channel.
Requires: a registered, identified nickname."
        ),
      category: :user,
      parameters: [
        %Parameter{
          name: "mode",
          required: false,
          type: :text,
          position: 0,
          description: dgettext("commands", "A mode of the game, like blitz")
        }
      ],
      examples: [dgettext("commands", "/lfg"), dgettext("commands", "/lfg blitz")]
    }
  end
end

# ex_dna:disable-for-next-line a game's own texts: literal gettext data, one module per game
defmodule RetroHexChat.Arcade.Content.Freedoom1 do
  @moduledoc false
  # ex_dna:disable-for-next-line a game's own texts: literal gettext data, one module per game
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Arcade.Content.Controls

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Freedoom: Phase 1 is a complete free replacement for Ultimate DOOM — 4 full episodes with 36 original levels, all under the BSD license. Every sprite, texture, sound effect, and music track has been recreated from scratch by the community."
        ),
        dgettext(
          "arcade",
          "The gameplay follows the classic DOOM formula: fast-paced FPS action with labyrinthine levels, keycard puzzles, and hordes of enemies. While the assets are different from id Software's originals, the game runs on the same engine and supports the same modding ecosystem."
        ),
        dgettext(
          "arcade",
          "As a fully open-source project, Freedoom serves both as a standalone game and as a free IWAD for running thousands of community-made DOOM mods and maps."
        )
      ],
      controls: Controls.adapt(Controls.doom()),
      tips: [
        dgettext(
          "arcade",
          "Freedoom's enemy designs differ from DOOM's but follow similar behavior patterns — learn the new sprites."
        ),
        dgettext(
          "arcade",
          "All 4 episodes are available — explore them all for varied level themes and increasing difficulty."
        ),
        dgettext(
          "arcade",
          "Compatible with most DOOM WADs and mods — the same engine powers it all."
        ),
        dgettext("arcade", "The automap (Tab) is your best friend in maze-like levels.")
      ]
    }
  end
end

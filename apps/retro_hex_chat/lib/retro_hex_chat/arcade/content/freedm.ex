# ex_dna:disable-for-next-line a game's own texts: literal gettext data, one module per game
defmodule RetroHexChat.Arcade.Content.Freedm do
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
          "FreeDM is a free, open-source collection of 32 deathmatch-focused maps for the DOOM engine. Designed for fast-paced multiplayer arena combat, each level is a compact, weapon-rich killing ground."
        ),
        dgettext(
          "arcade",
          "While originally created for multiplayer, FreeDM's maps work perfectly in single-player as exploration arenas. Each map is loaded with weapons, ammo, and power-ups — ideal for quick bursts of demon-slaying action."
        ),
        dgettext(
          "arcade",
          "Part of the Freedoom project, all assets are BSD-licensed and community-created. FreeDM serves as both a standalone experience and a free base for DOOM II deathmatch mods."
        )
      ],
      controls: Controls.adapt(Controls.doom()),
      tips: [
        dgettext(
          "arcade",
          "Maps are compact and weapon-dense — perfect for quick action sessions."
        ),
        dgettext("arcade", "Use IDCLEV## cheat (e.g., IDCLEV01) to jump between the 32 maps."),
        dgettext(
          "arcade",
          "Arena-style layouts mean enemies can come from any direction — stay moving."
        ),
        dgettext("arcade", "These maps are great for testing weapons and practicing movement.")
      ]
    }
  end
end

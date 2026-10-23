defmodule RetroHexChat.Arcade.Content.ChexQuest do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Arcade.Content.Controls

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Chex Quest (1996) is the legendary cereal box promotion that became a cult classic — a kid-friendly total conversion of DOOM where you play as the Chex Warrior, armed with the Zorcher to teleport slimy Flemoids back to their home dimension."
        ),
        dgettext(
          "arcade",
          "Included free in boxes of Chex cereal, it was the first video game ever distributed in a cereal box. Despite being a marketing gimmick, the 5-level campaign features surprisingly solid level design by Digital Café and has earned a devoted fanbase."
        ),
        dgettext(
          "arcade",
          "The game replaces all DOOM violence with family-friendly \"zorching\" — enemies aren't killed, they're teleported away. All blood and gore is replaced with green slime. It's a genuine piece of 90s gaming history."
        )
      ],
      controls:
        Controls.adapt(Controls.doom(),
          fire: {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire Zorcher")},
          jump: nil,
          weapons: {"1–5", dgettext("arcade", "Select Zorcher type")}
        ),
      tips: [
        dgettext(
          "arcade",
          "The Flemoids get tougher as you progress — save the powerful Zorchers for later levels."
        ),
        dgettext(
          "arcade",
          "Explore every corner — the levels have hidden areas with extra Zorch ammo."
        ),
        dgettext(
          "arcade",
          "The game is short (5 levels) but packed with nostalgia and surprisingly good design."
        ),
        dgettext(
          "arcade",
          "This is the original 1996 release — a genuine piece of gaming history from a cereal box."
        )
      ]
    }
  end
end

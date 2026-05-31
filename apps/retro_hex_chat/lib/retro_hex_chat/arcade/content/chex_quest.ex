defmodule RetroHexChat.Arcade.Content.ChexQuest do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

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
      controls: [
        {dgettext("arcade", "W / ↑"), dgettext("arcade", "Move forward")},
        {dgettext("arcade", "S / ↓"), dgettext("arcade", "Move backward")},
        {"A", dgettext("arcade", "Strafe left")},
        {"D", dgettext("arcade", "Strafe right")},
        {dgettext("arcade", "Mouse"), dgettext("arcade", "Aim / turn")},
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire Zorcher")},
        {"E", dgettext("arcade", "Use / open doors")},
        {"1–5", dgettext("arcade", "Select Zorcher type")},
        {"Tab", dgettext("arcade", "Toggle automap")},
        {dgettext("arcade", "Shift"), dgettext("arcade", "Run (hold)")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Menu")}
      ],
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

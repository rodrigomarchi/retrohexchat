defmodule RetroHexChat.Arcade.Content.ChexQuest do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Chex Quest (1996) is the legendary cereal box promotion that became a cult classic — a kid-friendly total conversion of DOOM where you play as the Chex Warrior, armed with the Zorcher to teleport slimy Flemoids back to their home dimension."
        ),
        gettext(
          "Included free in boxes of Chex cereal, it was the first video game ever distributed in a cereal box. Despite being a marketing gimmick, the 5-level campaign features surprisingly solid level design by Digital Café and has earned a devoted fanbase."
        ),
        gettext(
          "The game replaces all DOOM violence with family-friendly \"zorching\" — enemies aren't killed, they're teleported away. All blood and gore is replaced with green slime. It's a genuine piece of 90s gaming history."
        )
      ],
      controls: [
        {gettext("W / ↑"), gettext("Move forward")},
        {gettext("S / ↓"), gettext("Move backward")},
        {"A", gettext("Strafe left")},
        {"D", gettext("Strafe right")},
        {gettext("Mouse"), gettext("Aim / turn")},
        {gettext("Left Click"), gettext("Fire Zorcher")},
        {"E", gettext("Use / open doors")},
        {"1–5", gettext("Select Zorcher type")},
        {"Tab", gettext("Toggle automap")},
        {gettext("Shift"), gettext("Run (hold)")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "The Flemoids get tougher as you progress — save the powerful Zorchers for later levels."
        ),
        gettext("Explore every corner — the levels have hidden areas with extra Zorch ammo."),
        gettext(
          "The game is short (5 levels) but packed with nostalgia and surprisingly good design."
        ),
        gettext(
          "This is the original 1996 release — a genuine piece of gaming history from a cereal box."
        )
      ]
    }
  end
end

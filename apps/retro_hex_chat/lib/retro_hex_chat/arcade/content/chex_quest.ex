defmodule RetroHexChat.Arcade.Content.ChexQuest do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Chex Quest (1996) is the legendary cereal box promotion that became a cult classic — a kid-friendly total conversion of DOOM where you play as the Chex Warrior, armed with the Zorcher to teleport slimy Flemoids back to their home dimension.",
        "Included free in boxes of Chex cereal, it was the first video game ever distributed in a cereal box. Despite being a marketing gimmick, the 5-level campaign features surprisingly solid level design by Digital Café and has earned a devoted fanbase.",
        "The game replaces all DOOM violence with family-friendly \"zorching\" — enemies aren't killed, they're teleported away. All blood and gore is replaced with green slime. It's a genuine piece of 90s gaming history."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / turn"},
        {"Left Click", "Fire Zorcher"},
        {"E", "Use / open doors"},
        {"1–5", "Select Zorcher type"},
        {"Tab", "Toggle automap"},
        {"Shift", "Run (hold)"},
        {"Esc", "Menu"}
      ],
      tips: [
        "The Flemoids get tougher as you progress — save the powerful Zorchers for later levels.",
        "Explore every corner — the levels have hidden areas with extra Zorch ammo.",
        "The game is short (5 levels) but packed with nostalgia and surprisingly good design.",
        "This is the original 1996 release — a genuine piece of gaming history from a cereal box."
      ]
    }
  end
end

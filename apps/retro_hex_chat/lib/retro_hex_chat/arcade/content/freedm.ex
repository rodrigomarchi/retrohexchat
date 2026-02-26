defmodule RetroHexChat.Arcade.Content.Freedm do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "FreeDM is a free, open-source collection of 32 deathmatch-focused maps for the DOOM engine. Designed for fast-paced multiplayer arena combat, each level is a compact, weapon-rich killing ground.",
        "While originally created for multiplayer, FreeDM's maps work perfectly in single-player as exploration arenas. Each map is loaded with weapons, ammo, and power-ups — ideal for quick bursts of demon-slaying action.",
        "Part of the Freedoom project, all assets are BSD-licensed and community-created. FreeDM serves as both a standalone experience and a free base for DOOM II deathmatch mods."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / turn"},
        {"Left Click", "Fire weapon"},
        {"E", "Use / open doors"},
        {"Space", "Jump (PrBoom+)"},
        {"1–7", "Select weapon"},
        {"Tab", "Toggle automap"},
        {"Shift", "Run (hold)"},
        {"Esc", "Menu"}
      ],
      tips: [
        "Maps are compact and weapon-dense — perfect for quick action sessions.",
        "Use IDCLEV## cheat (e.g., IDCLEV01) to jump between the 32 maps.",
        "Arena-style layouts mean enemies can come from any direction — stay moving.",
        "These maps are great for testing weapons and practicing movement."
      ]
    }
  end
end

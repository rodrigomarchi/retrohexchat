defmodule RetroHexChat.Arcade.Content.Freedoom1 do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Freedoom: Phase 1 is a complete free replacement for Ultimate DOOM — 4 full episodes with 36 original levels, all under the BSD license. Every sprite, texture, sound effect, and music track has been recreated from scratch by the community.",
        "The gameplay follows the classic DOOM formula: fast-paced FPS action with labyrinthine levels, keycard puzzles, and hordes of enemies. While the assets are different from id Software's originals, the game runs on the same engine and supports the same modding ecosystem.",
        "As a fully open-source project, Freedoom serves both as a standalone game and as a free IWAD for running thousands of community-made DOOM mods and maps."
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
        "Freedoom's enemy designs differ from DOOM's but follow similar behavior patterns — learn the new sprites.",
        "All 4 episodes are available — explore them all for varied level themes and increasing difficulty.",
        "Compatible with most DOOM WADs and mods — the same engine powers it all.",
        "The automap (Tab) is your best friend in maze-like levels."
      ]
    }
  end
end

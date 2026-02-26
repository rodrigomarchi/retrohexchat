defmodule RetroHexChat.Arcade.Content.Rekkr do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "REKKR: Sunken Land (2018) is a Viking-themed total conversion for DOOM with stunning hand-drawn pixel art. Battle through Norse-inspired levels as a warrior fighting to reclaim lands overrun by the undead and dark forces.",
        "Every asset is lovingly hand-crafted — from the beautifully detailed environments (frozen fjords, ruined villages, underground caverns) to the unique weapon set including axes, bows, and runic magic. The art style is distinctly its own while honoring the DOOM engine's capabilities.",
        "Created by Matthew Little (Revae), REKKR won a Cacoward in 2018 for its exceptional quality. The standalone IWAD version runs independently of any commercial DOOM files."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / turn"},
        {"Left Click", "Fire / swing weapon"},
        {"E", "Use / open doors"},
        {"Space", "Jump (PrBoom+)"},
        {"1–7", "Select weapon"},
        {"Tab", "Toggle automap"},
        {"Shift", "Run (hold)"},
        {"Esc", "Menu"}
      ],
      tips: [
        "The melee weapons (axe, sword) are powerful and ammo-free — use them on weaker enemies.",
        "The bow is effective at range but arrows are limited — aim carefully.",
        "Runic magic weapons have area effects — great for crowd control in tight spaces.",
        "The hand-drawn pixel art hides secrets well — look for cracks and unusual wall textures.",
        "Won a Cacoward in 2018 — take your time and appreciate the craftsmanship."
      ]
    }
  end
end

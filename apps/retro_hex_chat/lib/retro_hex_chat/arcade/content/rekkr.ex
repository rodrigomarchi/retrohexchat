defmodule RetroHexChat.Arcade.Content.Rekkr do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "REKKR: Sunken Land (2018) is a Viking-themed total conversion for DOOM with stunning hand-drawn pixel art. Battle through Norse-inspired levels as a warrior fighting to reclaim lands overrun by the undead and dark forces."
        ),
        gettext(
          "Every asset is lovingly hand-crafted — from the beautifully detailed environments (frozen fjords, ruined villages, underground caverns) to the unique weapon set including axes, bows, and runic magic. The art style is distinctly its own while honoring the DOOM engine's capabilities."
        ),
        gettext(
          "Created by Matthew Little (Revae), REKKR won a Cacoward in 2018 for its exceptional quality. The standalone IWAD version runs independently of any commercial DOOM files."
        )
      ],
      controls: [
        {gettext("W / ↑"), gettext("Move forward")},
        {gettext("S / ↓"), gettext("Move backward")},
        {"A", gettext("Strafe left")},
        {"D", gettext("Strafe right")},
        {gettext("Mouse"), gettext("Aim / turn")},
        {gettext("Left Click"), gettext("Fire / swing weapon")},
        {"E", gettext("Use / open doors")},
        {gettext("Space"), gettext("Jump (PrBoom+)")},
        {"1–7", gettext("Select weapon")},
        {"Tab", gettext("Toggle automap")},
        {gettext("Shift"), gettext("Run (hold)")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "The melee weapons (axe, sword) are powerful and ammo-free — use them on weaker enemies."
        ),
        gettext("The bow is effective at range but arrows are limited — aim carefully."),
        gettext(
          "Runic magic weapons have area effects — great for crowd control in tight spaces."
        ),
        gettext(
          "The hand-drawn pixel art hides secrets well — look for cracks and unusual wall textures."
        ),
        gettext("Won a Cacoward in 2018 — take your time and appreciate the craftsmanship.")
      ]
    }
  end
end

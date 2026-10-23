defmodule RetroHexChat.Arcade.Content.Rekkr do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Arcade.Content.Controls

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "REKKR: Sunken Land (2018) is a Viking-themed total conversion for DOOM with stunning hand-drawn pixel art. Battle through Norse-inspired levels as a warrior fighting to reclaim lands overrun by the undead and dark forces."
        ),
        dgettext(
          "arcade",
          "Every asset is lovingly hand-crafted — from the beautifully detailed environments (frozen fjords, ruined villages, underground caverns) to the unique weapon set including axes, bows, and runic magic. The art style is distinctly its own while honoring the DOOM engine's capabilities."
        ),
        dgettext(
          "arcade",
          "Created by Matthew Little (Revae), REKKR won a Cacoward in 2018 for its exceptional quality. The standalone IWAD version runs independently of any commercial DOOM files."
        )
      ],
      controls:
        Controls.adapt(Controls.doom(),
          fire: {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire / swing weapon")}
        ),
      tips: [
        dgettext(
          "arcade",
          "The melee weapons (axe, sword) are powerful and ammo-free — use them on weaker enemies."
        ),
        dgettext(
          "arcade",
          "The bow is effective at range but arrows are limited — aim carefully."
        ),
        dgettext(
          "arcade",
          "Runic magic weapons have area effects — great for crowd control in tight spaces."
        ),
        dgettext(
          "arcade",
          "The hand-drawn pixel art hides secrets well — look for cracks and unusual wall textures."
        ),
        dgettext(
          "arcade",
          "Won a Cacoward in 2018 — take your time and appreciate the craftsmanship."
        )
      ]
    }
  end
end

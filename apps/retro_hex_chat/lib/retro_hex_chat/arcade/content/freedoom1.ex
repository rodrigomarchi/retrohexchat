defmodule RetroHexChat.Arcade.Content.Freedoom1 do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Freedoom: Phase 1 is a complete free replacement for Ultimate DOOM — 4 full episodes with 36 original levels, all under the BSD license. Every sprite, texture, sound effect, and music track has been recreated from scratch by the community."
        ),
        dgettext(
          "arcade",
          "The gameplay follows the classic DOOM formula: fast-paced FPS action with labyrinthine levels, keycard puzzles, and hordes of enemies. While the assets are different from id Software's originals, the game runs on the same engine and supports the same modding ecosystem."
        ),
        dgettext(
          "arcade",
          "As a fully open-source project, Freedoom serves both as a standalone game and as a free IWAD for running thousands of community-made DOOM mods and maps."
        )
      ],
      controls: [
        {dgettext("arcade", "W / ↑"), dgettext("arcade", "Move forward")},
        {dgettext("arcade", "S / ↓"), dgettext("arcade", "Move backward")},
        {"A", dgettext("arcade", "Strafe left")},
        {"D", dgettext("arcade", "Strafe right")},
        {dgettext("arcade", "Mouse"), dgettext("arcade", "Aim / turn")},
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire weapon")},
        {"E", dgettext("arcade", "Use / open doors")},
        {dgettext("arcade", "Space"), dgettext("arcade", "Jump (PrBoom+)")},
        {"1–7", dgettext("arcade", "Select weapon")},
        {"Tab", dgettext("arcade", "Toggle automap")},
        {dgettext("arcade", "Shift"), dgettext("arcade", "Run (hold)")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Menu")}
      ],
      tips: [
        dgettext(
          "arcade",
          "Freedoom's enemy designs differ from DOOM's but follow similar behavior patterns — learn the new sprites."
        ),
        dgettext(
          "arcade",
          "All 4 episodes are available — explore them all for varied level themes and increasing difficulty."
        ),
        dgettext(
          "arcade",
          "Compatible with most DOOM WADs and mods — the same engine powers it all."
        ),
        dgettext("arcade", "The automap (Tab) is your best friend in maze-like levels.")
      ]
    }
  end
end

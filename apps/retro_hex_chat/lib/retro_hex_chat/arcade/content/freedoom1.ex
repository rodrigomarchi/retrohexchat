defmodule RetroHexChat.Arcade.Content.Freedoom1 do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Freedoom: Phase 1 is a complete free replacement for Ultimate DOOM — 4 full episodes with 36 original levels, all under the BSD license. Every sprite, texture, sound effect, and music track has been recreated from scratch by the community."
        ),
        gettext(
          "The gameplay follows the classic DOOM formula: fast-paced FPS action with labyrinthine levels, keycard puzzles, and hordes of enemies. While the assets are different from id Software's originals, the game runs on the same engine and supports the same modding ecosystem."
        ),
        gettext(
          "As a fully open-source project, Freedoom serves both as a standalone game and as a free IWAD for running thousands of community-made DOOM mods and maps."
        )
      ],
      controls: [
        {gettext("W / ↑"), gettext("Move forward")},
        {gettext("S / ↓"), gettext("Move backward")},
        {"A", gettext("Strafe left")},
        {"D", gettext("Strafe right")},
        {gettext("Mouse"), gettext("Aim / turn")},
        {gettext("Left Click"), gettext("Fire weapon")},
        {"E", gettext("Use / open doors")},
        {gettext("Space"), gettext("Jump (PrBoom+)")},
        {"1–7", gettext("Select weapon")},
        {"Tab", gettext("Toggle automap")},
        {gettext("Shift"), gettext("Run (hold)")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "Freedoom's enemy designs differ from DOOM's but follow similar behavior patterns — learn the new sprites."
        ),
        gettext(
          "All 4 episodes are available — explore them all for varied level themes and increasing difficulty."
        ),
        gettext("Compatible with most DOOM WADs and mods — the same engine powers it all."),
        gettext("The automap (Tab) is your best friend in maze-like levels.")
      ]
    }
  end
end

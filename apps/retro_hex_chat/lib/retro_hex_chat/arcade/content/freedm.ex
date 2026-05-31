defmodule RetroHexChat.Arcade.Content.Freedm do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "FreeDM is a free, open-source collection of 32 deathmatch-focused maps for the DOOM engine. Designed for fast-paced multiplayer arena combat, each level is a compact, weapon-rich killing ground."
        ),
        dgettext(
          "arcade",
          "While originally created for multiplayer, FreeDM's maps work perfectly in single-player as exploration arenas. Each map is loaded with weapons, ammo, and power-ups — ideal for quick bursts of demon-slaying action."
        ),
        dgettext(
          "arcade",
          "Part of the Freedoom project, all assets are BSD-licensed and community-created. FreeDM serves as both a standalone experience and a free base for DOOM II deathmatch mods."
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
          "Maps are compact and weapon-dense — perfect for quick action sessions."
        ),
        dgettext("arcade", "Use IDCLEV## cheat (e.g., IDCLEV01) to jump between the 32 maps."),
        dgettext(
          "arcade",
          "Arena-style layouts mean enemies can come from any direction — stay moving."
        ),
        dgettext("arcade", "These maps are great for testing weapons and practicing movement.")
      ]
    }
  end
end

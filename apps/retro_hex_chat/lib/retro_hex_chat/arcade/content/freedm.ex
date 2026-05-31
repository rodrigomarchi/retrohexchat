defmodule RetroHexChat.Arcade.Content.Freedm do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "FreeDM is a free, open-source collection of 32 deathmatch-focused maps for the DOOM engine. Designed for fast-paced multiplayer arena combat, each level is a compact, weapon-rich killing ground."
        ),
        gettext(
          "While originally created for multiplayer, FreeDM's maps work perfectly in single-player as exploration arenas. Each map is loaded with weapons, ammo, and power-ups — ideal for quick bursts of demon-slaying action."
        ),
        gettext(
          "Part of the Freedoom project, all assets are BSD-licensed and community-created. FreeDM serves as both a standalone experience and a free base for DOOM II deathmatch mods."
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
        gettext("Maps are compact and weapon-dense — perfect for quick action sessions."),
        gettext("Use IDCLEV## cheat (e.g., IDCLEV01) to jump between the 32 maps."),
        gettext("Arena-style layouts mean enemies can come from any direction — stay moving."),
        gettext("These maps are great for testing weapons and practicing movement.")
      ]
    }
  end
end

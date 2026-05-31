defmodule RetroHexChat.Arcade.Content.Librequake do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "LibreQuake is a complete free and open-source replacement for Quake — original levels, models, textures, sounds, and music all created by the community under the BSD license. No commercial Quake files are needed."
        ),
        dgettext(
          "arcade",
          "The project aims to provide a fully libre alternative to id Software's original assets while maintaining the fast-paced, atmospheric gameplay that made Quake legendary. Community contributors have recreated the entire game experience from scratch."
        ),
        dgettext(
          "arcade",
          "LibreQuake runs on the same QuakeSpasm engine as the original, delivering full 3D gameplay with mouselook, jumping, and all the movement mechanics Quake is known for."
        )
      ],
      controls: [
        {dgettext("arcade", "W / ↑"), dgettext("arcade", "Move forward")},
        {dgettext("arcade", "S / ↓"), dgettext("arcade", "Move backward")},
        {"A", dgettext("arcade", "Strafe left")},
        {"D", dgettext("arcade", "Strafe right")},
        {dgettext("arcade", "Mouse"), dgettext("arcade", "Aim / look")},
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Fire weapon")},
        {"E", dgettext("arcade", "Use / interact")},
        {dgettext("arcade", "Space"), dgettext("arcade", "Jump")},
        {"1–8", dgettext("arcade", "Select weapon")},
        {"Tab", dgettext("arcade", "Show scores")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Menu")}
      ],
      tips: [
        dgettext(
          "arcade",
          "LibreQuake uses original community-made assets — the weapons and enemies look different from Quake but play similarly."
        ),
        dgettext(
          "arcade",
          "The movement system is identical to Quake — bunny hopping and strafe jumping work here too."
        ),
        dgettext("arcade", "All content is BSD-licensed — the ultimate libre FPS experience."),
        dgettext(
          "arcade",
          "Explore thoroughly — the community level designers have hidden secrets throughout."
        )
      ]
    }
  end
end

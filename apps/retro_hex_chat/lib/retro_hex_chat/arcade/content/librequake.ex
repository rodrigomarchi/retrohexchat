defmodule RetroHexChat.Arcade.Content.Librequake do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "LibreQuake is a complete free and open-source replacement for Quake — original levels, models, textures, sounds, and music all created by the community under the BSD license. No commercial Quake files are needed."
        ),
        gettext(
          "The project aims to provide a fully libre alternative to id Software's original assets while maintaining the fast-paced, atmospheric gameplay that made Quake legendary. Community contributors have recreated the entire game experience from scratch."
        ),
        gettext(
          "LibreQuake runs on the same QuakeSpasm engine as the original, delivering full 3D gameplay with mouselook, jumping, and all the movement mechanics Quake is known for."
        )
      ],
      controls: [
        {gettext("W / ↑"), gettext("Move forward")},
        {gettext("S / ↓"), gettext("Move backward")},
        {"A", gettext("Strafe left")},
        {"D", gettext("Strafe right")},
        {gettext("Mouse"), gettext("Aim / look")},
        {gettext("Left Click"), gettext("Fire weapon")},
        {"E", gettext("Use / interact")},
        {gettext("Space"), gettext("Jump")},
        {"1–8", gettext("Select weapon")},
        {"Tab", gettext("Show scores")},
        {gettext("Esc"), gettext("Menu")}
      ],
      tips: [
        gettext(
          "LibreQuake uses original community-made assets — the weapons and enemies look different from Quake but play similarly."
        ),
        gettext(
          "The movement system is identical to Quake — bunny hopping and strafe jumping work here too."
        ),
        gettext("All content is BSD-licensed — the ultimate libre FPS experience."),
        gettext(
          "Explore thoroughly — the community level designers have hidden secrets throughout."
        )
      ]
    }
  end
end

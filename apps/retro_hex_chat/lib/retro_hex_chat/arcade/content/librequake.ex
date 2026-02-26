defmodule RetroHexChat.Arcade.Content.Librequake do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "LibreQuake is a complete free and open-source replacement for Quake — original levels, models, textures, sounds, and music all created by the community under the BSD license. No commercial Quake files are needed.",
        "The project aims to provide a fully libre alternative to id Software's original assets while maintaining the fast-paced, atmospheric gameplay that made Quake legendary. Community contributors have recreated the entire game experience from scratch.",
        "LibreQuake runs on the same QuakeSpasm engine as the original, delivering full 3D gameplay with mouselook, jumping, and all the movement mechanics Quake is known for."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / look"},
        {"Left Click", "Fire weapon"},
        {"E", "Use / interact"},
        {"Space", "Jump"},
        {"1–8", "Select weapon"},
        {"Tab", "Show scores"},
        {"Esc", "Menu"}
      ],
      tips: [
        "LibreQuake uses original community-made assets — the weapons and enemies look different from Quake but play similarly.",
        "The movement system is identical to Quake — bunny hopping and strafe jumping work here too.",
        "All content is BSD-licensed — the ultimate libre FPS experience.",
        "Explore thoroughly — the community level designers have hidden secrets throughout."
      ]
    }
  end
end

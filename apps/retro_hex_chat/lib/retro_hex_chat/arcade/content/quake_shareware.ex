defmodule RetroHexChat.Arcade.Content.QuakeShareware do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Quake (1996) — \"Dimension of the Doomed\" — the shareware episode that pushed PC gaming into true 3D. Created by id Software, Quake was the first major FPS with fully 3D environments, polygonal models, and real-time lighting."
        ),
        gettext(
          "Episode 1 takes you through four dimensions of Lovecraftian horror: medieval castles, dark crypts, and otherworldly realms filled with Shamblers, Fiends, Ogres, and other nightmarish creatures. The atmospheric soundtrack by Trent Reznor (Nine Inch Nails) adds to the oppressive mood."
        ),
        gettext(
          "This shareware release features the complete first episode (8 levels plus a secret level) running on the QuakeSpasm engine compiled to WebAssembly. The engine delivers the full Quake experience with mouselook and modern controls."
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
          "Mouselook is enabled by default — aim up and down to hit enemies on different elevations."
        ),
        gettext(
          "The Grenade Launcher is devastating in tight corridors — bounce grenades around corners."
        ),
        gettext(
          "Shamblers are immune to splash damage — use the Super Nailgun or Lightning Gun instead."
        ),
        gettext("Swimming sections require managing your air supply — look for surface pockets."),
        gettext(
          "Rocket jumping is possible (jump + shoot down) to reach secret areas, at the cost of health."
        )
      ]
    }
  end
end

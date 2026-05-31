defmodule RetroHexChat.Arcade.Content.QuakeShareware do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Quake (1996) — \"Dimension of the Doomed\" — the shareware episode that pushed PC gaming into true 3D. Created by id Software, Quake was the first major FPS with fully 3D environments, polygonal models, and real-time lighting."
        ),
        dgettext(
          "arcade",
          "Episode 1 takes you through four dimensions of Lovecraftian horror: medieval castles, dark crypts, and otherworldly realms filled with Shamblers, Fiends, Ogres, and other nightmarish creatures. The atmospheric soundtrack by Trent Reznor (Nine Inch Nails) adds to the oppressive mood."
        ),
        dgettext(
          "arcade",
          "This shareware release features the complete first episode (8 levels plus a secret level) running on the QuakeSpasm engine compiled to WebAssembly. The engine delivers the full Quake experience with mouselook and modern controls."
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
          "Mouselook is enabled by default — aim up and down to hit enemies on different elevations."
        ),
        dgettext(
          "arcade",
          "The Grenade Launcher is devastating in tight corridors — bounce grenades around corners."
        ),
        dgettext(
          "arcade",
          "Shamblers are immune to splash damage — use the Super Nailgun or Lightning Gun instead."
        ),
        dgettext(
          "arcade",
          "Swimming sections require managing your air supply — look for surface pockets."
        ),
        dgettext(
          "arcade",
          "Rocket jumping is possible (jump + shoot down) to reach secret areas, at the cost of health."
        )
      ]
    }
  end
end

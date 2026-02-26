defmodule RetroHexChat.Arcade.Content.QuakeShareware do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Quake (1996) — \"Dimension of the Doomed\" — the shareware episode that pushed PC gaming into true 3D. Created by id Software, Quake was the first major FPS with fully 3D environments, polygonal models, and real-time lighting.",
        "Episode 1 takes you through four dimensions of Lovecraftian horror: medieval castles, dark crypts, and otherworldly realms filled with Shamblers, Fiends, Ogres, and other nightmarish creatures. The atmospheric soundtrack by Trent Reznor (Nine Inch Nails) adds to the oppressive mood.",
        "This shareware release features the complete first episode (8 levels plus a secret level) running on the QuakeSpasm engine compiled to WebAssembly. The engine delivers the full Quake experience with mouselook and modern controls."
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
        "Mouselook is enabled by default — aim up and down to hit enemies on different elevations.",
        "The Grenade Launcher is devastating in tight corridors — bounce grenades around corners.",
        "Shamblers are immune to splash damage — use the Super Nailgun or Lightning Gun instead.",
        "Swimming sections require managing your air supply — look for surface pockets.",
        "Rocket jumping is possible (jump + shoot down) to reach secret areas, at the cost of health."
      ]
    }
  end
end

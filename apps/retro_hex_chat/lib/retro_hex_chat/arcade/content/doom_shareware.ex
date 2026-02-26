defmodule RetroHexChat.Arcade.Content.DoomShareware do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "The original shareware episode of DOOM (1993) — \"Knee-Deep in the Dead\" — the game that launched the FPS genre into the mainstream. Nine levels of demon-infested corridors on the Martian moon Phobos, where a UAC teleportation experiment has gone horribly wrong.",
        "As a lone space marine, fight your way through military bases overrun by hellspawn using an arsenal that includes the iconic shotgun, chaingun, and rocket launcher. The level design by John Romero and Sandy Petersen remains a masterclass in non-linear FPS map design.",
        "This is the freely distributable shareware release — Episode 1 of the original DOOM, exactly as id Software released it in December 1993. It runs on the PrBoom+ engine compiled to WebAssembly."
      ],
      controls: [
        {"W / ↑", "Move forward"},
        {"S / ↓", "Move backward"},
        {"A", "Strafe left"},
        {"D", "Strafe right"},
        {"Mouse", "Aim / turn"},
        {"Left Click", "Fire weapon"},
        {"E", "Use / open doors"},
        {"Space", "Jump (PrBoom+)"},
        {"1–7", "Select weapon"},
        {"Tab", "Toggle automap"},
        {"Shift", "Run (hold)"},
        {"Esc", "Menu"}
      ],
      tips: [
        "Hold Shift to run — movement speed doubles, essential for dodging projectiles.",
        "Use F6 for quicksave and F9 for quickload — save often, especially before new areas.",
        "Secrets are everywhere — look for misaligned wall textures and listen for hidden doors.",
        "The chainsaw is devastating against Pinkies (Demons) — it stunlocks them completely.",
        "Strafe-running (forward + strafe simultaneously) makes you move ~40% faster than running straight."
      ]
    }
  end
end

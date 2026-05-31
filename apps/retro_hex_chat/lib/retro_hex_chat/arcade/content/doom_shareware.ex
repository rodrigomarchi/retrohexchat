defmodule RetroHexChat.Arcade.Content.DoomShareware do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "The original shareware episode of DOOM (1993) — \"Knee-Deep in the Dead\" — the game that launched the FPS genre into the mainstream. Nine levels of demon-infested corridors on the Martian moon Phobos, where a UAC teleportation experiment has gone horribly wrong."
        ),
        gettext(
          "As a lone space marine, fight your way through military bases overrun by hellspawn using an arsenal that includes the iconic shotgun, chaingun, and rocket launcher. The level design by John Romero and Sandy Petersen remains a masterclass in non-linear FPS map design."
        ),
        gettext(
          "This is the freely distributable shareware release — Episode 1 of the original DOOM, exactly as id Software released it in December 1993. It runs on the PrBoom+ engine compiled to WebAssembly."
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
        gettext("Hold Shift to run — movement speed doubles, essential for dodging projectiles."),
        gettext(
          "Use F6 for quicksave and F9 for quickload — save often, especially before new areas."
        ),
        gettext(
          "Secrets are everywhere — look for misaligned wall textures and listen for hidden doors."
        ),
        gettext(
          "The chainsaw is devastating against Pinkies (Demons) — it stunlocks them completely."
        ),
        gettext(
          "Strafe-running (forward + strafe simultaneously) makes you move ~40% faster than running straight."
        )
      ]
    }
  end
end

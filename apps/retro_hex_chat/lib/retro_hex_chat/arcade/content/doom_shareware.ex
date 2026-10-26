# ex_dna:disable-for-next-line a game's own texts: literal gettext data, one module per game
defmodule RetroHexChat.Arcade.Content.DoomShareware do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.Arcade.Content.Controls

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "The original shareware episode of DOOM (1993) — \"Knee-Deep in the Dead\" — the game that launched the FPS genre into the mainstream. Nine levels of demon-infested corridors on the Martian moon Phobos, where a UAC teleportation experiment has gone horribly wrong."
        ),
        dgettext(
          "arcade",
          "As a lone space marine, fight your way through military bases overrun by hellspawn using an arsenal that includes the iconic shotgun, chaingun, and rocket launcher. The level design by John Romero and Sandy Petersen remains a masterclass in non-linear FPS map design."
        ),
        dgettext(
          "arcade",
          "This is the freely distributable shareware release — Episode 1 of the original DOOM, exactly as id Software released it in December 1993. It runs on the PrBoom+ engine compiled to WebAssembly."
        )
      ],
      controls: Controls.adapt(Controls.doom()),
      tips: [
        dgettext(
          "arcade",
          "Hold Shift to run — movement speed doubles, essential for dodging projectiles."
        ),
        dgettext(
          "arcade",
          "Use F6 for quicksave and F9 for quickload — save often, especially before new areas."
        ),
        dgettext(
          "arcade",
          "Secrets are everywhere — look for misaligned wall textures and listen for hidden doors."
        ),
        dgettext(
          "arcade",
          "The chainsaw is devastating against Pinkies (Demons) — it stunlocks them completely."
        ),
        dgettext(
          "arcade",
          "Strafe-running (forward + strafe simultaneously) makes you move ~40% faster than running straight."
        )
      ]
    }
  end
end

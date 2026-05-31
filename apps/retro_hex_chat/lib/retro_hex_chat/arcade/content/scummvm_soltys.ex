defmodule RetroHexChat.Arcade.Content.ScummvmSoltys do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Soltys (1995) is a charmingly absurd Polish point-and-click adventure by LK Avalon. Your grandfather has been kidnapped by underground pirates, and you must rescue him by navigating a surreal world full of bizarre characters and creative puzzles."
        ),
        dgettext(
          "arcade",
          "The game's humor is distinctly Polish — surreal, absurdist, and full of wordplay that transcends language barriers through visual gags and slapstick comedy. The puzzle design is inventive, often requiring unconventional thinking."
        ),
        dgettext(
          "arcade",
          "Originally a Polish commercial release, Soltys was later made freeware. It's a beloved piece of Polish gaming history and a hidden gem of the European adventure game scene. Runs on ScummVM via the CGE engine."
        )
      ],
      controls: [
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Walk / interact with object")},
        {dgettext("arcade", "Right Click"), dgettext("arcade", "Examine object")},
        {"F5", dgettext("arcade", "Save / load game")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Skip cutscene")},
        {dgettext("arcade", "Space"), dgettext("arcade", "Pause game")}
      ],
      tips: [
        dgettext(
          "arcade",
          "Think creatively — Soltys puzzles often follow dream logic rather than real-world logic."
        ),
        dgettext(
          "arcade",
          "Click on everything — interactive hotspots can be small and unexpected."
        ),
        dgettext(
          "arcade",
          "The game's humor rewards curiosity — try unusual item combinations for funny reactions."
        ),
        dgettext(
          "arcade",
          "The interface is simple and streamlined — left-click does most of the work."
        ),
        dgettext(
          "arcade",
          "Don't get frustrated by the surreal logic — that's part of the charm."
        )
      ]
    }
  end
end

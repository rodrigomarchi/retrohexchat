defmodule RetroHexChat.Arcade.Content.ScummvmSoltys do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Soltys (1995) is a charmingly absurd Polish point-and-click adventure by LK Avalon. Your grandfather has been kidnapped by underground pirates, and you must rescue him by navigating a surreal world full of bizarre characters and creative puzzles."
        ),
        gettext(
          "The game's humor is distinctly Polish — surreal, absurdist, and full of wordplay that transcends language barriers through visual gags and slapstick comedy. The puzzle design is inventive, often requiring unconventional thinking."
        ),
        gettext(
          "Originally a Polish commercial release, Soltys was later made freeware. It's a beloved piece of Polish gaming history and a hidden gem of the European adventure game scene. Runs on ScummVM via the CGE engine."
        )
      ],
      controls: [
        {gettext("Left Click"), gettext("Walk / interact with object")},
        {gettext("Right Click"), gettext("Examine object")},
        {"F5", gettext("Save / load game")},
        {gettext("Esc"), gettext("Skip cutscene")},
        {gettext("Space"), gettext("Pause game")}
      ],
      tips: [
        gettext(
          "Think creatively — Soltys puzzles often follow dream logic rather than real-world logic."
        ),
        gettext("Click on everything — interactive hotspots can be small and unexpected."),
        gettext(
          "The game's humor rewards curiosity — try unusual item combinations for funny reactions."
        ),
        gettext("The interface is simple and streamlined — left-click does most of the work."),
        gettext("Don't get frustrated by the surreal logic — that's part of the charm.")
      ]
    }
  end
end

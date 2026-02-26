defmodule RetroHexChat.Arcade.Content.ScummvmSoltys do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Soltys (1995) is a charmingly absurd Polish point-and-click adventure by LK Avalon. Your grandfather has been kidnapped by underground pirates, and you must rescue him by navigating a surreal world full of bizarre characters and creative puzzles.",
        "The game's humor is distinctly Polish — surreal, absurdist, and full of wordplay that transcends language barriers through visual gags and slapstick comedy. The puzzle design is inventive, often requiring unconventional thinking.",
        "Originally a Polish commercial release, Soltys was later made freeware. It's a beloved piece of Polish gaming history and a hidden gem of the European adventure game scene. Runs on ScummVM via the CGE engine."
      ],
      controls: [
        {"Left Click", "Walk / interact with object"},
        {"Right Click", "Examine object"},
        {"F5", "Save / load game"},
        {"Esc", "Skip cutscene"},
        {"Space", "Pause game"}
      ],
      tips: [
        "Think creatively — Soltys puzzles often follow dream logic rather than real-world logic.",
        "Click on everything — interactive hotspots can be small and unexpected.",
        "The game's humor rewards curiosity — try unusual item combinations for funny reactions.",
        "The interface is simple and streamlined — left-click does most of the work.",
        "Don't get frustrated by the surreal logic — that's part of the charm."
      ]
    }
  end
end

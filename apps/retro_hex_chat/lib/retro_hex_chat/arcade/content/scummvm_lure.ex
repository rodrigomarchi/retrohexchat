defmodule RetroHexChat.Arcade.Content.ScummvmLure do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Lure of the Temptress (1992) is Revolution Software's debut game — a medieval fantasy adventure featuring the innovative Virtual Theatre engine. The village of Turnvale has been conquered by the sorceress Selena and her army of orcs known as Skorl.",
        "As Diermot, a young peasant, you must free Turnvale from Selena's grip. The Virtual Theatre system means NPCs follow their own schedules, walk around town independently, and react to events — groundbreaking for 1992 and still impressive today.",
        "Made freeware by Revolution Software, Lure of the Temptress is a piece of adventure game history. While shorter and rougher than later Revolution games (Beneath a Steel Sky, Broken Sword), its autonomous NPC system was years ahead of its time."
      ],
      controls: [
        {"Left Click", "Walk / interact"},
        {"Right Click", "Open verb menu"},
        {"F5", "Save / load game"},
        {"Esc", "Skip cutscene"},
        {"Space", "Pause game"},
        {".", "Skip dialogue line"}
      ],
      tips: [
        "NPCs wander on their own schedules — if someone isn't where you expect, wait or look elsewhere.",
        "The verb menu (right-click) is essential — try different verbs on objects and people.",
        "Ratpouch (your companion) can be told to perform actions — sometimes he can go where you can't.",
        "The game is relatively short but the NPC AI can make timing-based puzzles tricky.",
        "Save often — the Skorl guards can catch you, and some situations are unrecoverable."
      ]
    }
  end
end

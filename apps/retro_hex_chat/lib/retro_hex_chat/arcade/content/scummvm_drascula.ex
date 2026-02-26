defmodule RetroHexChat.Arcade.Content.ScummvmDrascula do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Drascula: The Vampire Strikes Back (1996) is a hilarious Spanish point-and-click adventure by Alcachofa Soft. British real estate agent John Hacker travels to Transylvania and must defeat the vampire Count Drascula, who has kidnapped the beautiful BJ to make her his bride.",
        "The game is a loving parody of vampire fiction, packed with pop culture references, absurd humor, and fourth-wall-breaking jokes. From reanimating Frankenstein's monster to visiting a nightclub for vampires, the puzzles are as creative as they are bizarre.",
        "Originally a Spanish commercial release, Drascula was later made freeware by its developers. The full game features voice acting and runs on ScummVM with CD audio support."
      ],
      controls: [
        {"Left Click", "Walk / interact with object"},
        {"Right Click", "Examine object"},
        {"F5", "Save / load game"},
        {"Esc", "Skip cutscene"},
        {"Space", "Pause game"},
        {".", "Skip dialogue line"}
      ],
      tips: [
        "Try everything with everything — the game's puzzle logic follows cartoon comedy rules.",
        "Talk to all characters exhaustively — some puzzles require specific dialogue choices.",
        "The humor is very European and reference-heavy — enjoy the absurdity.",
        "Don't forget to look at items in your inventory — descriptions often contain hints.",
        "The game spans multiple locations — if stuck, revisit previous areas after new events."
      ]
    }
  end
end

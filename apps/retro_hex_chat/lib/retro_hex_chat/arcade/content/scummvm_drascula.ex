defmodule RetroHexChat.Arcade.Content.ScummvmDrascula do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Drascula: The Vampire Strikes Back (1996) is a hilarious Spanish point-and-click adventure by Alcachofa Soft. British real estate agent John Hacker travels to Transylvania and must defeat the vampire Count Drascula, who has kidnapped the beautiful BJ to make her his bride."
        ),
        dgettext(
          "arcade",
          "The game is a loving parody of vampire fiction, packed with pop culture references, absurd humor, and fourth-wall-breaking jokes. From reanimating Frankenstein's monster to visiting a nightclub for vampires, the puzzles are as creative as they are bizarre."
        ),
        dgettext(
          "arcade",
          "Originally a Spanish commercial release, Drascula was later made freeware by its developers. The full game features voice acting and runs on ScummVM with CD audio support."
        )
      ],
      controls: [
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Walk / interact with object")},
        {dgettext("arcade", "Right Click"), dgettext("arcade", "Examine object")},
        {"F5", dgettext("arcade", "Save / load game")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Skip cutscene")},
        {dgettext("arcade", "Space"), dgettext("arcade", "Pause game")},
        {".", dgettext("arcade", "Skip dialogue line")}
      ],
      tips: [
        dgettext(
          "arcade",
          "Try everything with everything — the game's puzzle logic follows cartoon comedy rules."
        ),
        dgettext(
          "arcade",
          "Talk to all characters exhaustively — some puzzles require specific dialogue choices."
        ),
        dgettext(
          "arcade",
          "The humor is very European and reference-heavy — enjoy the absurdity."
        ),
        dgettext(
          "arcade",
          "Don't forget to look at items in your inventory — descriptions often contain hints."
        ),
        dgettext(
          "arcade",
          "The game spans multiple locations — if stuck, revisit previous areas after new events."
        )
      ]
    }
  end
end

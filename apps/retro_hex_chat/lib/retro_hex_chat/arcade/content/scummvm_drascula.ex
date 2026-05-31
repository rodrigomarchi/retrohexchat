defmodule RetroHexChat.Arcade.Content.ScummvmDrascula do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Drascula: The Vampire Strikes Back (1996) is a hilarious Spanish point-and-click adventure by Alcachofa Soft. British real estate agent John Hacker travels to Transylvania and must defeat the vampire Count Drascula, who has kidnapped the beautiful BJ to make her his bride."
        ),
        gettext(
          "The game is a loving parody of vampire fiction, packed with pop culture references, absurd humor, and fourth-wall-breaking jokes. From reanimating Frankenstein's monster to visiting a nightclub for vampires, the puzzles are as creative as they are bizarre."
        ),
        gettext(
          "Originally a Spanish commercial release, Drascula was later made freeware by its developers. The full game features voice acting and runs on ScummVM with CD audio support."
        )
      ],
      controls: [
        {gettext("Left Click"), gettext("Walk / interact with object")},
        {gettext("Right Click"), gettext("Examine object")},
        {"F5", gettext("Save / load game")},
        {gettext("Esc"), gettext("Skip cutscene")},
        {gettext("Space"), gettext("Pause game")},
        {".", gettext("Skip dialogue line")}
      ],
      tips: [
        gettext(
          "Try everything with everything — the game's puzzle logic follows cartoon comedy rules."
        ),
        gettext(
          "Talk to all characters exhaustively — some puzzles require specific dialogue choices."
        ),
        gettext("The humor is very European and reference-heavy — enjoy the absurdity."),
        gettext(
          "Don't forget to look at items in your inventory — descriptions often contain hints."
        ),
        gettext(
          "The game spans multiple locations — if stuck, revisit previous areas after new events."
        )
      ]
    }
  end
end

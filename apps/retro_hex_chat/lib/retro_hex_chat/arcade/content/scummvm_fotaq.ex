defmodule RetroHexChat.Arcade.Content.ScummvmFotaq do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Flight of the Amazon Queen (1995) is a comic point-and-click adventure in the style of Indiana Jones and Monkey Island. You play as Joe King, a pilot-for-hire whose plane crash-lands in the Amazon jungle while transporting a famous actress."
        ),
        dgettext(
          "arcade",
          "What starts as a simple rescue mission quickly spirals into a plot involving a mad scientist, an army of dinosaur-human hybrids, and the fate of the entire Amazon. The game is packed with witty dialogue, clever puzzles, and laugh-out-loud humor."
        ),
        dgettext(
          "arcade",
          "Made freeware by the developers, Flight of the Amazon Queen features full voice acting on the CD version. It runs on ScummVM and is considered one of the hidden gems of the 90s adventure game era."
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
          "Talk to everyone and exhaust all dialogue options — Joe's quips are half the fun."
        ),
        dgettext(
          "arcade",
          "Combine inventory items — some puzzles require creative item combinations."
        ),
        dgettext(
          "arcade",
          "The game opens up significantly after the crash landing — explore every screen thoroughly."
        ),
        dgettext(
          "arcade",
          "Some puzzles have multiple solutions — experiment with different approaches."
        ),
        dgettext(
          "arcade",
          "The humor is very LucasArts-inspired — expect puns, pop culture references, and silliness."
        )
      ]
    }
  end
end

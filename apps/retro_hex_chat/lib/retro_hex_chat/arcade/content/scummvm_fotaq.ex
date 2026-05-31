defmodule RetroHexChat.Arcade.Content.ScummvmFotaq do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Flight of the Amazon Queen (1995) is a comic point-and-click adventure in the style of Indiana Jones and Monkey Island. You play as Joe King, a pilot-for-hire whose plane crash-lands in the Amazon jungle while transporting a famous actress."
        ),
        gettext(
          "What starts as a simple rescue mission quickly spirals into a plot involving a mad scientist, an army of dinosaur-human hybrids, and the fate of the entire Amazon. The game is packed with witty dialogue, clever puzzles, and laugh-out-loud humor."
        ),
        gettext(
          "Made freeware by the developers, Flight of the Amazon Queen features full voice acting on the CD version. It runs on ScummVM and is considered one of the hidden gems of the 90s adventure game era."
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
          "Talk to everyone and exhaust all dialogue options — Joe's quips are half the fun."
        ),
        gettext("Combine inventory items — some puzzles require creative item combinations."),
        gettext(
          "The game opens up significantly after the crash landing — explore every screen thoroughly."
        ),
        gettext("Some puzzles have multiple solutions — experiment with different approaches."),
        gettext(
          "The humor is very LucasArts-inspired — expect puns, pop culture references, and silliness."
        )
      ]
    }
  end
end

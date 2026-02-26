defmodule RetroHexChat.Arcade.Content.ScummvmFotaq do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Flight of the Amazon Queen (1995) is a comic point-and-click adventure in the style of Indiana Jones and Monkey Island. You play as Joe King, a pilot-for-hire whose plane crash-lands in the Amazon jungle while transporting a famous actress.",
        "What starts as a simple rescue mission quickly spirals into a plot involving a mad scientist, an army of dinosaur-human hybrids, and the fate of the entire Amazon. The game is packed with witty dialogue, clever puzzles, and laugh-out-loud humor.",
        "Made freeware by the developers, Flight of the Amazon Queen features full voice acting on the CD version. It runs on ScummVM and is considered one of the hidden gems of the 90s adventure game era."
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
        "Talk to everyone and exhaust all dialogue options — Joe's quips are half the fun.",
        "Combine inventory items — some puzzles require creative item combinations.",
        "The game opens up significantly after the crash landing — explore every screen thoroughly.",
        "Some puzzles have multiple solutions — experiment with different approaches.",
        "The humor is very LucasArts-inspired — expect puns, pop culture references, and silliness."
      ]
    }
  end
end

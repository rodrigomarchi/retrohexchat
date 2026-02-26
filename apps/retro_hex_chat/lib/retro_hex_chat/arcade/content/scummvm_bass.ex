defmodule RetroHexChat.Arcade.Content.ScummvmBass do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Beneath a Steel Sky (1994) is a cyberpunk point-and-click adventure by Revolution Software, set in a dystopian future Australia. Robert Foster was raised in the radioactive wasteland known as \"the Gap\" but is kidnapped and brought to Union City — a massive, stratified metropolis ruled by the supercomputer LINC.",
        "With his robot companion Joey (whose personality chip can be inserted into different robot bodies), Robert must navigate the city's social layers, uncover conspiracies, and discover the truth about his past. The game features artwork by Dave Gibbons (Watchmen) and a rich cyberpunk narrative.",
        "Made freeware by Revolution Software in 2003, Beneath a Steel Sky is widely considered one of the greatest point-and-click adventures ever made. It runs on ScummVM with full CD voice acting."
      ],
      controls: [
        {"Left Click", "Walk / interact with object"},
        {"Right Click", "Examine / open verb menu"},
        {"Drag item", "Combine inventory items"},
        {"F5", "Save / load game"},
        {"Ctrl + F5", "ScummVM options"},
        {"Esc", "Skip cutscene"},
        {"Space", "Pause game"},
        {".", "Skip dialogue line"}
      ],
      tips: [
        "Talk to everyone multiple times — NPCs often have new dialogue after events change.",
        "Joey can be inserted into different robot bodies — some puzzles require specific robot forms.",
        "Pay attention to the social stratification — each city level has its own culture and rules.",
        "The game's humor is subtle and British — read item descriptions for entertaining commentary.",
        "Save frequently — some puzzle sequences are complex and easy to get stuck in."
      ]
    }
  end
end

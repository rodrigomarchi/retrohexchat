defmodule RetroHexChat.Arcade.Content.ScummvmBass do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Beneath a Steel Sky (1994) is a cyberpunk point-and-click adventure by Revolution Software, set in a dystopian future Australia. Robert Foster was raised in the radioactive wasteland known as \"the Gap\" but is kidnapped and brought to Union City — a massive, stratified metropolis ruled by the supercomputer LINC."
        ),
        gettext(
          "With his robot companion Joey (whose personality chip can be inserted into different robot bodies), Robert must navigate the city's social layers, uncover conspiracies, and discover the truth about his past. The game features artwork by Dave Gibbons (Watchmen) and a rich cyberpunk narrative."
        ),
        gettext(
          "Made freeware by Revolution Software in 2003, Beneath a Steel Sky is widely considered one of the greatest point-and-click adventures ever made. It runs on ScummVM with full CD voice acting."
        )
      ],
      controls: [
        {gettext("Left Click"), gettext("Walk / interact with object")},
        {gettext("Right Click"), gettext("Examine / open verb menu")},
        {gettext("Drag item"), gettext("Combine inventory items")},
        {"F5", gettext("Save / load game")},
        {gettext("Ctrl + F5"), gettext("ScummVM options")},
        {gettext("Esc"), gettext("Skip cutscene")},
        {gettext("Space"), gettext("Pause game")},
        {".", gettext("Skip dialogue line")}
      ],
      tips: [
        gettext(
          "Talk to everyone multiple times — NPCs often have new dialogue after events change."
        ),
        gettext(
          "Joey can be inserted into different robot bodies — some puzzles require specific robot forms."
        ),
        gettext(
          "Pay attention to the social stratification — each city level has its own culture and rules."
        ),
        gettext(
          "The game's humor is subtle and British — read item descriptions for entertaining commentary."
        ),
        gettext("Save frequently — some puzzle sequences are complex and easy to get stuck in.")
      ]
    }
  end
end

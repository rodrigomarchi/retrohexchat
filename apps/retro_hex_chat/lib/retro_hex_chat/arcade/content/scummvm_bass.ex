defmodule RetroHexChat.Arcade.Content.ScummvmBass do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        dgettext(
          "arcade",
          "Beneath a Steel Sky (1994) is a cyberpunk point-and-click adventure by Revolution Software, set in a dystopian future Australia. Robert Foster was raised in the radioactive wasteland known as \"the Gap\" but is kidnapped and brought to Union City — a massive, stratified metropolis ruled by the supercomputer LINC."
        ),
        dgettext(
          "arcade",
          "With his robot companion Joey (whose personality chip can be inserted into different robot bodies), Robert must navigate the city's social layers, uncover conspiracies, and discover the truth about his past. The game features artwork by Dave Gibbons (Watchmen) and a rich cyberpunk narrative."
        ),
        dgettext(
          "arcade",
          "Made freeware by Revolution Software in 2003, Beneath a Steel Sky is widely considered one of the greatest point-and-click adventures ever made. It runs on ScummVM with full CD voice acting."
        )
      ],
      controls: [
        {dgettext("arcade", "Left Click"), dgettext("arcade", "Walk / interact with object")},
        {dgettext("arcade", "Right Click"), dgettext("arcade", "Examine / open verb menu")},
        {dgettext("arcade", "Drag item"), dgettext("arcade", "Combine inventory items")},
        {"F5", dgettext("arcade", "Save / load game")},
        {dgettext("arcade", "Ctrl + F5"), dgettext("arcade", "ScummVM options")},
        {dgettext("arcade", "Esc"), dgettext("arcade", "Skip cutscene")},
        {dgettext("arcade", "Space"), dgettext("arcade", "Pause game")},
        {".", dgettext("arcade", "Skip dialogue line")}
      ],
      tips: [
        dgettext(
          "arcade",
          "Talk to everyone multiple times — NPCs often have new dialogue after events change."
        ),
        dgettext(
          "arcade",
          "Joey can be inserted into different robot bodies — some puzzles require specific robot forms."
        ),
        dgettext(
          "arcade",
          "Pay attention to the social stratification — each city level has its own culture and rules."
        ),
        dgettext(
          "arcade",
          "The game's humor is subtle and British — read item descriptions for entertaining commentary."
        ),
        dgettext(
          "arcade",
          "Save frequently — some puzzle sequences are complex and easy to get stuck in."
        )
      ]
    }
  end
end

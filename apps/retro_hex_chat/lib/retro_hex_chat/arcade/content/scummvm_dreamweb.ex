defmodule RetroHexChat.Arcade.Content.ScummvmDreamweb do
  @moduledoc false

  @spec data() :: map()
  def data do
    %{
      about: [
        "Dreamweb (1994) is a dark, atmospheric cyberpunk adventure by Creative Reality. You play as Ryan, an ordinary man plagued by nightmares about the Dreamweb — a mystical barrier that protects reality from descending into chaos. Seven guardians maintain the web, but they've become corrupt.",
        "The game uses a unique top-down perspective rare for adventure games, creating a claustrophobic and voyeuristic atmosphere. The dystopian city is rendered in gritty pixel art, and the story deals with mature themes of obsession, violence, and the nature of reality.",
        "This is the full CD version with voice acting, made freeware by Empire Interactive. Dreamweb was ahead of its time in narrative ambition and remains a cult favorite among adventure game enthusiasts."
      ],
      controls: [
        {"Left Click", "Walk / interact"},
        {"Right Click", "Examine object"},
        {"F5", "Save / load game"},
        {"Esc", "Skip cutscene"},
        {"Space", "Pause game"},
        {".", "Skip dialogue line"}
      ],
      tips: [
        "The game has a dark, mature tone — it deals with heavy themes not common in 90s adventures.",
        "Inventory management matters — you have limited carrying capacity, so choose wisely.",
        "The top-down view means pixel-hunting is harder — move the cursor slowly over scenes.",
        "Read Ryan's diary (included as a PDF in the original release) for important backstory.",
        "Pay attention to the dreamworld sequences — they contain clues for the real world."
      ]
    }
  end
end

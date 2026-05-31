defmodule RetroHexChat.Arcade.Content.ScummvmDreamweb do
  @moduledoc false
  use Gettext, backend: RetroHexChat.Gettext

  @spec data() :: map()
  def data do
    %{
      about: [
        gettext(
          "Dreamweb (1994) is a dark, atmospheric cyberpunk adventure by Creative Reality. You play as Ryan, an ordinary man plagued by nightmares about the Dreamweb — a mystical barrier that protects reality from descending into chaos. Seven guardians maintain the web, but they've become corrupt."
        ),
        gettext(
          "The game uses a unique top-down perspective rare for adventure games, creating a claustrophobic and voyeuristic atmosphere. The dystopian city is rendered in gritty pixel art, and the story deals with mature themes of obsession, violence, and the nature of reality."
        ),
        gettext(
          "This is the full CD version with voice acting, made freeware by Empire Interactive. Dreamweb was ahead of its time in narrative ambition and remains a cult favorite among adventure game enthusiasts."
        )
      ],
      controls: [
        {gettext("Left Click"), gettext("Walk / interact")},
        {gettext("Right Click"), gettext("Examine object")},
        {"F5", gettext("Save / load game")},
        {gettext("Esc"), gettext("Skip cutscene")},
        {gettext("Space"), gettext("Pause game")},
        {".", gettext("Skip dialogue line")}
      ],
      tips: [
        gettext(
          "The game has a dark, mature tone — it deals with heavy themes not common in 90s adventures."
        ),
        gettext(
          "Inventory management matters — you have limited carrying capacity, so choose wisely."
        ),
        gettext(
          "The top-down view means pixel-hunting is harder — move the cursor slowly over scenes."
        ),
        gettext(
          "Read Ryan's diary (included as a PDF in the original release) for important backstory."
        ),
        gettext(
          "Pay attention to the dreamworld sequences — they contain clues for the real world."
        )
      ]
    }
  end
end

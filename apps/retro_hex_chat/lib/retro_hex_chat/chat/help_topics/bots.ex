defmodule RetroHexChat.Chat.HelpTopics.Bots do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "botservice",
        title: "BotService Overview",
        category: "Bots",
        keywords: [
          "bot",
          "botservice",
          "bot service",
          "bots",
          "capabilities",
          "automation",
          "greeter",
          "custom commands"
        ],
        icon: :icon_wrench,
        description:
          "Create and manage extensible bots with pluggable capabilities for channel automation."
      },
      %{
        id: "bot-command",
        title: "/bot Command Reference",
        category: "Bots",
        keywords: [
          "bot command",
          "/bot",
          "bot create",
          "bot destroy",
          "bot join",
          "bot part",
          "bot enable",
          "bot disable",
          "bot set",
          "bot addcmd",
          "bot delcmd"
        ],
        icon: :icon_terminal,
        description:
          "Reference for all /bot subcommands: create, destroy, join, part, enable, disable, set, addcmd, delcmd."
      },
      %{
        id: "bot-custom-commands",
        title: "Bot Custom Commands",
        category: "Bots",
        keywords: [
          "bot commands",
          "custom commands",
          "!prefix",
          "trigger",
          "response",
          "addcmd",
          "delcmd"
        ],
        icon: :icon_code,
        description:
          "How to create and use custom bot commands (!prefix trigger) for automated responses."
      },
      %{
        id: "bot-dice",
        title: "Bot Dice Capability",
        category: "Bots",
        keywords: [
          "dice",
          "roll",
          "d20",
          "rpg",
          "random",
          "bot dice",
          "dice notation",
          "keep highest",
          "keep lowest"
        ],
        icon: :icon_dice,
        description:
          "RPG dice rolling with standard notation (NdS, modifiers, keep highest/lowest)."
      },
      %{
        id: "bot-trivia",
        title: "Bot Trivia Capability",
        category: "Bots",
        keywords: [
          "trivia",
          "quiz",
          "questions",
          "score",
          "bot trivia",
          "categories",
          "game",
          "answer"
        ],
        icon: :icon_question,
        description:
          "Interactive trivia quiz with multiple categories, scoring, and configurable timers."
      },
      %{
        id: "bot-scheduler",
        title: "Bot Scheduler Capability",
        category: "Bots",
        keywords: [
          "scheduler",
          "schedule",
          "interval",
          "daily",
          "periodic",
          "bot scheduler",
          "cron",
          "timer"
        ],
        icon: :icon_clock,
        description: "Schedule periodic or daily messages to channels automatically."
      },
      %{
        id: "bot-rss",
        title: "Bot RSS Capability",
        category: "Bots",
        keywords: [
          "rss",
          "feed",
          "atom",
          "news",
          "bot rss",
          "poll",
          "syndication",
          "updates"
        ],
        icon: :icon_rss,
        description: "Monitor RSS/Atom feeds and post new items to channels automatically."
      },
      %{
        id: "bot-moderation",
        title: "Bot Moderation Capability",
        category: "Bots",
        keywords: [
          "moderation",
          "mod",
          "filter",
          "spam",
          "flood",
          "blocked words",
          "bot moderation",
          "auto-mod"
        ],
        icon: :icon_shield,
        description:
          "Auto-moderation: word filtering, spam/flood detection, caps lock abuse prevention."
      }
    ]
  end
end

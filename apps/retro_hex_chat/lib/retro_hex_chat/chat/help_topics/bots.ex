defmodule RetroHexChat.Chat.HelpTopics.Bots do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "botservice",
        title: gettext("BotService Overview"),
        category: gettext("Bots"),
        keywords: [
          "bot",
          "botservice",
          gettext("bot service"),
          "bots",
          "capabilities",
          "automation",
          "greeter",
          gettext("custom commands")
        ],
        icon: :icon_wrench,
        description:
          gettext(
            "Create and manage extensible bots with pluggable capabilities for channel automation."
          )
      },
      %{
        id: "bot-command",
        title: gettext("/bot Command Reference"),
        category: gettext("Bots"),
        keywords: [
          gettext("bot command"),
          "/bot",
          gettext("bot create"),
          gettext("bot destroy"),
          gettext("bot join"),
          gettext("bot part"),
          gettext("bot enable"),
          gettext("bot disable"),
          gettext("bot set"),
          gettext("bot addcmd"),
          gettext("bot delcmd")
        ],
        icon: :icon_terminal,
        description:
          gettext(
            "Reference for all /bot subcommands: create, destroy, join, part, enable, disable, set, addcmd, delcmd."
          )
      },
      %{
        id: "bot-custom-commands",
        title: gettext("Bot Custom Commands"),
        category: gettext("Bots"),
        keywords: [
          gettext("bot commands"),
          gettext("custom commands"),
          gettext("!prefix"),
          "trigger",
          "response",
          "addcmd",
          "delcmd"
        ],
        icon: :icon_code,
        description:
          gettext(
            "How to create and use custom bot commands (!prefix trigger) for automated responses."
          )
      },
      %{
        id: "bot-dice",
        title: gettext("Bot Dice Capability"),
        category: gettext("Bots"),
        keywords: [
          "dice",
          "roll",
          "d20",
          "rpg",
          "random",
          gettext("bot dice"),
          gettext("dice notation"),
          gettext("keep highest"),
          gettext("keep lowest")
        ],
        icon: :icon_dice,
        description:
          gettext(
            "RPG dice rolling with standard notation (NdS, modifiers, keep highest/lowest)."
          )
      },
      %{
        id: "bot-trivia",
        title: gettext("Bot Trivia Capability"),
        category: gettext("Bots"),
        keywords: [
          "trivia",
          "quiz",
          "questions",
          "score",
          gettext("bot trivia"),
          "categories",
          "game",
          "answer"
        ],
        icon: :icon_question,
        description:
          gettext(
            "Interactive trivia quiz with multiple categories, scoring, and configurable timers."
          )
      },
      %{
        id: "bot-scheduler",
        title: gettext("Bot Scheduler Capability"),
        category: gettext("Bots"),
        keywords: [
          "scheduler",
          "schedule",
          "interval",
          "daily",
          "periodic",
          gettext("bot scheduler"),
          "cron",
          "timer"
        ],
        icon: :icon_clock,
        description: gettext("Schedule periodic or daily messages to channels automatically.")
      },
      %{
        id: "bot-rss",
        title: gettext("Bot RSS Capability"),
        category: gettext("Bots"),
        keywords: [
          "rss",
          "feed",
          "atom",
          "news",
          gettext("bot rss"),
          "poll",
          "syndication",
          "updates"
        ],
        icon: :icon_rss,
        description:
          gettext("Monitor RSS/Atom feeds and post new items to channels automatically.")
      },
      %{
        id: "bot-moderation",
        title: gettext("Bot Moderation Capability"),
        category: gettext("Bots"),
        keywords: [
          "moderation",
          "mod",
          "filter",
          "spam",
          "flood",
          "blocked words",
          gettext("bot moderation"),
          "auto-mod"
        ],
        icon: :icon_shield,
        description:
          gettext(
            "Auto-moderation: word filtering, spam/flood detection, caps lock abuse prevention."
          )
      }
    ]
  end
end

defmodule RetroHexChat.Chat.HelpTopics.Bots do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "botservice",
        title: dgettext("help", "BotService Overview"),
        category: dgettext("help", "Bots"),
        keywords: [
          "bot",
          "botservice",
          dgettext("help", "bot service"),
          "bots",
          "capabilities",
          "automation",
          "greeter",
          "bot management",
          "management dialog",
          dgettext("help", "custom commands")
        ],
        icon: :icon_wrench,
        description:
          dgettext(
            "help",
            "Create and manage extensible bots with pluggable capabilities for channel automation, including the admin Bot Management dialog."
          )
      },
      %{
        id: "bot-command",
        title: dgettext("help", "/bot Command Reference"),
        category: dgettext("help", "Bots"),
        keywords: [
          dgettext("help", "bot command"),
          "/bot",
          dgettext("help", "bot create"),
          dgettext("help", "bot destroy"),
          dgettext("help", "bot join"),
          dgettext("help", "bot part"),
          dgettext("help", "bot enable"),
          dgettext("help", "bot disable"),
          dgettext("help", "bot set"),
          dgettext("help", "bot addcmd"),
          dgettext("help", "bot delcmd"),
          "bot management"
        ],
        icon: :icon_terminal,
        description:
          dgettext(
            "help",
            "Reference for all /bot subcommands and the admin dialog opened by /bot with no arguments."
          )
      },
      %{
        id: "bot-custom-commands",
        title: dgettext("help", "Bot Custom Commands"),
        category: dgettext("help", "Bots"),
        keywords: [
          dgettext("help", "bot commands"),
          dgettext("help", "custom commands"),
          dgettext("help", "!prefix"),
          "trigger",
          "response",
          "addcmd",
          "delcmd"
        ],
        icon: :icon_code,
        description:
          dgettext(
            "help",
            "How to create and use custom bot commands (!prefix trigger) for automated responses."
          )
      },
      %{
        id: "bot-dice",
        title: dgettext("help", "Bot Dice Capability"),
        category: dgettext("help", "Bots"),
        keywords: [
          "dice",
          "roll",
          "d20",
          "rpg",
          "random",
          dgettext("help", "bot dice"),
          dgettext("help", "dice notation"),
          dgettext("help", "keep highest"),
          dgettext("help", "keep lowest")
        ],
        icon: :icon_dice,
        description:
          dgettext(
            "help",
            "RPG dice rolling with standard notation (NdS, modifiers, keep highest/lowest)."
          )
      },
      %{
        id: "bot-trivia",
        title: dgettext("help", "Bot Trivia Capability"),
        category: dgettext("help", "Bots"),
        keywords: [
          "trivia",
          "quiz",
          "questions",
          "score",
          dgettext("help", "bot trivia"),
          "categories",
          "game",
          "answer"
        ],
        icon: :icon_question,
        description:
          dgettext(
            "help",
            "Interactive trivia quiz with multiple categories, scoring, and configurable timers."
          )
      },
      %{
        id: "bot-scheduler",
        title: dgettext("help", "Bot Scheduler Capability"),
        category: dgettext("help", "Bots"),
        keywords: [
          "scheduler",
          "schedule",
          "interval",
          "daily",
          "periodic",
          dgettext("help", "bot scheduler"),
          "cron",
          "timer"
        ],
        icon: :icon_clock,
        description:
          dgettext("help", "Schedule periodic or daily messages to channels automatically.")
      },
      %{
        id: "bot-rss",
        title: dgettext("help", "Bot RSS Capability"),
        category: dgettext("help", "Bots"),
        keywords: [
          "rss",
          "feed",
          "atom",
          "news",
          dgettext("help", "bot rss"),
          "poll",
          "syndication",
          "updates"
        ],
        icon: :icon_rss,
        description:
          dgettext("help", "Monitor RSS/Atom feeds and post new items to channels automatically.")
      },
      %{
        id: "bot-moderation",
        title: dgettext("help", "Bot Moderation Capability"),
        category: dgettext("help", "Bots"),
        keywords: [
          "moderation",
          "mod",
          "filter",
          "spam",
          "flood",
          "blocked words",
          dgettext("help", "bot moderation"),
          "auto-mod"
        ],
        icon: :icon_shield,
        description:
          dgettext(
            "help",
            "Auto-moderation: word filtering, spam/flood detection, caps lock abuse prevention."
          )
      }
    ]
  end
end

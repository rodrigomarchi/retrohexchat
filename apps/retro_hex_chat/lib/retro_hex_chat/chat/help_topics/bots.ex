defmodule RetroHexChat.Chat.HelpTopics.Bots do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "botservice",
        title: "BotService Overview",
        category: "Services",
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
        category: "Commands",
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
        category: "Features",
        keywords: [
          "bot commands",
          "custom commands",
          "!prefix",
          "trigger",
          "response",
          "addcmd",
          "delcmd"
        ],
        icon: :icon_star,
        description:
          "How to create and use custom bot commands (!prefix trigger) for automated responses."
      }
    ]
  end
end

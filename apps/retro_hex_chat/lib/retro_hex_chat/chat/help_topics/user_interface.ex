defmodule RetroHexChat.Chat.HelpTopics.UserInterface do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "ui-overview",
        title: dgettext("help", "User Interface Overview"),
        category: dgettext("help", "User Interface"),
        keywords: ["ui", "interface", "layout", "window", "mdi"],
        icon: :icon_laptop,
        description:
          dgettext(
            "help",
            "Overview of the RetroHexChat interface layout including panels, toolbar, and navigation."
          )
      },
      %{
        id: "ui-conversations",
        title: dgettext("help", "Conversations"),
        category: dgettext("help", "User Interface"),
        keywords: ["conversations", "sidebar", "navigation", "left pane", "channels", "popular"],
        icon: :icon_tab_conversations,
        description:
          dgettext(
            "help",
            "Navigate channels and private conversations using the left-side conversations panel."
          )
      },
      %{
        id: "ui-tab-bar",
        title: dgettext("help", "Tab Bar"),
        category: dgettext("help", "User Interface"),
        keywords: ["tab", dgettext("help", "tab bar"), "switch", dgettext("help", "close tab")],
        icon: :icon_tab_channel,
        description:
          dgettext(
            "help",
            "Switch between channels and conversations using the tab bar at the top of the chat area."
          )
      },
      %{
        id: "ui-nicklist",
        title: dgettext("help", "User List"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "nicklist",
          dgettext("help", "user list"),
          dgettext("help", "nick list"),
          "users",
          dgettext("help", "conversations users")
        ],
        icon: :icon_tab_nicklist,
        description:
          dgettext(
            "help",
            "View and interact with users in the current channel through the right-side user list."
          )
      },
      %{
        id: "ui-topic-bar",
        title: dgettext("help", "Topic Bar"),
        category: dgettext("help", "User Interface"),
        keywords: [
          dgettext("help", "topic bar"),
          dgettext("help", "channel info"),
          dgettext("help", "modes display")
        ],
        icon: :icon_btn_set_topic,
        description:
          dgettext(
            "help",
            "View the channel topic and active modes in the bar below the tab bar."
          )
      },
      %{
        id: "ui-context-menu",
        title: dgettext("help", "Context Menu"),
        category: dgettext("help", "User Interface"),
        keywords: [
          dgettext("help", "context menu"),
          dgettext("help", "right click"),
          "right-click",
          "popup"
        ],
        icon: :icon_dialog_custom_menus,
        description:
          dgettext(
            "help",
            "Access user actions and channel operations through right-click context menus."
          )
      },
      %{
        id: "ui-status-tab",
        title: dgettext("help", "Status Tab"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "status",
          dgettext("help", "status tab"),
          dgettext("help", "status window"),
          dgettext("help", "system messages"),
          "observability"
        ],
        icon: :icon_tab_status,
        description:
          dgettext(
            "help",
            "View server messages, connection events, and system notifications in the Status tab."
          )
      },
      %{
        id: "ui-toolbar",
        title: dgettext("help", "Toolbar"),
        category: dgettext("help", "User Interface"),
        keywords: ["toolbar", "buttons", "icons", "tools", "menu", "notify"],
        icon: :icon_group_tools,
        description:
          dgettext(
            "help",
            "Access common features through the menu bar and toolbar options."
          )
      },
      %{
        id: "empty-states",
        title: dgettext("help", "Empty States"),
        category: dgettext("help", "User Interface"),
        keywords: [
          "empty",
          dgettext("help", "empty state"),
          "placeholder",
          dgettext("help", "no messages"),
          dgettext("help", "no users"),
          dgettext("help", "no channels"),
          dgettext("help", "no urls")
        ],
        icon: :icon_folder,
        description:
          dgettext(
            "help",
            "Helpful placeholders shown when lists are empty, guiding you on what to do next."
          )
      }
    ]
  end
end

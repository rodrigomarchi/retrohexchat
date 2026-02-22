defmodule RetroHexChat.Chat.HelpTopics.UserInterface do
  @moduledoc false

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "ui-overview",
        title: "User Interface Overview",
        category: "User Interface",
        keywords: ["ui", "interface", "layout", "window", "mdi"],
        icon: :icon_laptop,
        description:
          "Overview of the RetroHexChat interface layout including panels, toolbar, and navigation."
      },
      %{
        id: "ui-conversations",
        title: "Conversations",
        category: "User Interface",
        keywords: ["conversations", "sidebar", "navigation", "left pane", "channels", "popular"],
        icon: :icon_tab_conversations,
        description:
          "Navigate channels and private conversations using the left-side conversations panel."
      },
      %{
        id: "ui-tab-bar",
        title: "Tab Bar",
        category: "User Interface",
        keywords: ["tab", "tab bar", "switch", "close tab"],
        icon: :icon_tab_channel,
        description:
          "Switch between channels and conversations using the tab bar at the top of the chat area."
      },
      %{
        id: "ui-nicklist",
        title: "User List",
        category: "User Interface",
        keywords: ["nicklist", "user list", "nick list", "users", "conversations users"],
        icon: :icon_tab_nicklist,
        description:
          "View and interact with users in the current channel through the right-side user list."
      },
      %{
        id: "ui-topic-bar",
        title: "Topic Bar",
        category: "User Interface",
        keywords: ["topic bar", "channel info", "modes display"],
        icon: :icon_btn_set_topic,
        description: "View the channel topic and active modes in the bar below the tab bar."
      },
      %{
        id: "ui-context-menu",
        title: "Context Menu",
        category: "User Interface",
        keywords: ["context menu", "right click", "right-click", "popup"],
        icon: :icon_dialog_custom_menus,
        description:
          "Access user actions and channel operations through right-click context menus."
      },
      %{
        id: "ui-status-tab",
        title: "Status Tab",
        category: "User Interface",
        keywords: ["status", "status tab", "status window", "system messages", "observability"],
        icon: :icon_tab_status,
        description:
          "View server messages, connection events, and system notifications in the Status tab."
      },
      %{
        id: "ui-toolbar",
        title: "Toolbar",
        category: "User Interface",
        keywords: ["toolbar", "buttons", "icons", "tools", "menu"],
        icon: :icon_group_tools,
        description: "Access all features through the toolbar buttons organized in six groups."
      },
      %{
        id: "empty-states",
        title: "Empty States",
        category: "User Interface",
        keywords: [
          "empty",
          "empty state",
          "placeholder",
          "no messages",
          "no users",
          "no channels",
          "no urls"
        ],
        icon: :icon_folder,
        description:
          "Helpful placeholders shown when lists are empty, guiding you on what to do next."
      }
    ]
  end
end

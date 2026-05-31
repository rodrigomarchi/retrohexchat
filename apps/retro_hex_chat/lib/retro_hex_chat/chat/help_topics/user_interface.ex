defmodule RetroHexChat.Chat.HelpTopics.UserInterface do
  @moduledoc false

  use Gettext, backend: RetroHexChat.Gettext

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "ui-overview",
        title: gettext("User Interface Overview"),
        category: gettext("User Interface"),
        keywords: ["ui", "interface", "layout", "window", "mdi"],
        icon: :icon_laptop,
        description:
          gettext(
            "Overview of the RetroHexChat interface layout including panels, toolbar, and navigation."
          )
      },
      %{
        id: "ui-conversations",
        title: gettext("Conversations"),
        category: gettext("User Interface"),
        keywords: ["conversations", "sidebar", "navigation", "left pane", "channels", "popular"],
        icon: :icon_tab_conversations,
        description:
          gettext(
            "Navigate channels and private conversations using the left-side conversations panel."
          )
      },
      %{
        id: "ui-tab-bar",
        title: gettext("Tab Bar"),
        category: gettext("User Interface"),
        keywords: ["tab", gettext("tab bar"), "switch", gettext("close tab")],
        icon: :icon_tab_channel,
        description:
          gettext(
            "Switch between channels and conversations using the tab bar at the top of the chat area."
          )
      },
      %{
        id: "ui-nicklist",
        title: gettext("User List"),
        category: gettext("User Interface"),
        keywords: [
          "nicklist",
          gettext("user list"),
          gettext("nick list"),
          "users",
          gettext("conversations users")
        ],
        icon: :icon_tab_nicklist,
        description:
          gettext(
            "View and interact with users in the current channel through the right-side user list."
          )
      },
      %{
        id: "ui-topic-bar",
        title: gettext("Topic Bar"),
        category: gettext("User Interface"),
        keywords: [gettext("topic bar"), gettext("channel info"), gettext("modes display")],
        icon: :icon_btn_set_topic,
        description:
          gettext("View the channel topic and active modes in the bar below the tab bar.")
      },
      %{
        id: "ui-context-menu",
        title: gettext("Context Menu"),
        category: gettext("User Interface"),
        keywords: [gettext("context menu"), gettext("right click"), "right-click", "popup"],
        icon: :icon_dialog_custom_menus,
        description:
          gettext("Access user actions and channel operations through right-click context menus.")
      },
      %{
        id: "ui-status-tab",
        title: gettext("Status Tab"),
        category: gettext("User Interface"),
        keywords: [
          "status",
          gettext("status tab"),
          gettext("status window"),
          gettext("system messages"),
          "observability"
        ],
        icon: :icon_tab_status,
        description:
          gettext(
            "View server messages, connection events, and system notifications in the Status tab."
          )
      },
      %{
        id: "ui-toolbar",
        title: gettext("Toolbar"),
        category: gettext("User Interface"),
        keywords: ["toolbar", "buttons", "icons", "tools", "menu"],
        icon: :icon_group_tools,
        description:
          gettext("Access all features through the toolbar buttons organized in six groups.")
      },
      %{
        id: "empty-states",
        title: gettext("Empty States"),
        category: gettext("User Interface"),
        keywords: [
          "empty",
          gettext("empty state"),
          "placeholder",
          gettext("no messages"),
          gettext("no users"),
          gettext("no channels"),
          gettext("no urls")
        ],
        icon: :icon_folder,
        description:
          gettext(
            "Helpful placeholders shown when lists are empty, guiding you on what to do next."
          )
      }
    ]
  end
end

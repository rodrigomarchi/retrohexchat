defmodule RetroHexChat.Chat.HelpTopics.UserInterface do
  @moduledoc false

  @help_dir Path.join(:code.priv_dir(:retro_hex_chat), "help")

  @external_resource Path.join(@help_dir, "ui-overview.html")
  @external_resource Path.join(@help_dir, "ui-treebar.html")
  @external_resource Path.join(@help_dir, "ui-tab-bar.html")
  @external_resource Path.join(@help_dir, "ui-nicklist.html")
  @external_resource Path.join(@help_dir, "ui-topic-bar.html")
  @external_resource Path.join(@help_dir, "ui-context-menu.html")
  @external_resource Path.join(@help_dir, "ui-status-tab.html")
  @external_resource Path.join(@help_dir, "ui-toolbar.html")
  @external_resource Path.join(@help_dir, "empty-states.html")

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "ui-overview",
        title: "User Interface Overview",
        category: "User Interface",
        keywords: ["ui", "interface", "layout", "window", "mdi"],
        content: File.read!(Path.join(@help_dir, "ui-overview.html"))
      },
      %{
        id: "ui-treebar",
        title: "Treebar",
        category: "User Interface",
        keywords: ["treebar", "tree", "sidebar", "navigation", "left pane"],
        content: File.read!(Path.join(@help_dir, "ui-treebar.html"))
      },
      %{
        id: "ui-tab-bar",
        title: "Tab Bar",
        category: "User Interface",
        keywords: ["tab", "tab bar", "switch", "close tab"],
        content: File.read!(Path.join(@help_dir, "ui-tab-bar.html"))
      },
      %{
        id: "ui-nicklist",
        title: "Nicklist",
        category: "User Interface",
        keywords: ["nicklist", "user list", "nick list", "users", "right pane"],
        content: File.read!(Path.join(@help_dir, "ui-nicklist.html"))
      },
      %{
        id: "ui-topic-bar",
        title: "Topic Bar",
        category: "User Interface",
        keywords: ["topic bar", "channel info", "modes display"],
        content: File.read!(Path.join(@help_dir, "ui-topic-bar.html"))
      },
      %{
        id: "ui-context-menu",
        title: "Context Menu",
        category: "User Interface",
        keywords: ["context menu", "right click", "right-click", "popup"],
        content: File.read!(Path.join(@help_dir, "ui-context-menu.html"))
      },
      %{
        id: "ui-status-tab",
        title: "Status Tab",
        category: "User Interface",
        keywords: ["status", "status tab", "status window", "system messages", "observability"],
        content: File.read!(Path.join(@help_dir, "ui-status-tab.html"))
      },
      %{
        id: "ui-toolbar",
        title: "Toolbar",
        category: "User Interface",
        keywords: ["toolbar", "buttons", "icons", "tools", "menu"],
        content: File.read!(Path.join(@help_dir, "ui-toolbar.html"))
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
        content: File.read!(Path.join(@help_dir, "empty-states.html"))
      }
    ]
  end
end

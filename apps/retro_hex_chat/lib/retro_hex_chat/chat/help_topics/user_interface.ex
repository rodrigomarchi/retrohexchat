defmodule RetroHexChat.Chat.HelpTopics.UserInterface do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "ui-overview",
        title: "User Interface Overview",
        category: "User Interface",
        keywords: ["ui", "interface", "layout", "window", "mdi"],
        content:
          "<h3>User Interface Overview</h3>" <>
            "<p>RetroHexChat uses a classic mIRC-style layout with Windows 98 aesthetics.</p>" <>
            "<h4>Layout</h4>" <>
            "<p><strong>Menu Bar:</strong> File, Edit, View, Tools, Help menus at the top.<br/>" <>
            "<strong>Toolbar:</strong> Quick-access buttons for common actions.<br/>" <>
            "<strong>Tab Bar:</strong> Switch between Status, channels, and PM tabs.<br/>" <>
            "<strong>Topic Bar:</strong> Shows the current channel name, modes, and topic.<br/>" <>
            "<strong>Treebar:</strong> Hierarchical navigation (left pane) with channels and PMs.<br/>" <>
            "<strong>Chat Area:</strong> Message display with formatting and clickable URLs.<br/>" <>
            "<strong>Nicklist:</strong> User list for the current channel (right pane).<br/>" <>
            "<strong>Formatting Toolbar:</strong> Bold, italic, underline, color, and strip controls.<br/>" <>
            "<strong>Status Bar:</strong> Your nickname, current channel, and user count.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"ui-treebar\">Treebar</a> · " <>
            "<a href=\"#\" data-help-topic=\"ui-tab-bar\">Tab Bar</a> · " <>
            "<a href=\"#\" data-help-topic=\"ui-nicklist\">Nicklist</a></p>"
      },
      %{
        id: "ui-treebar",
        title: "Treebar",
        category: "User Interface",
        keywords: ["treebar", "tree", "sidebar", "navigation", "left pane"],
        content:
          "<h3>Treebar</h3>" <>
            "<p>The treebar is the left navigation pane showing your channels, PMs, and the notify list in a tree view.</p>" <>
            "<h4>Features</h4>" <>
            "<p>Click a channel or PM to switch to it. Channels with unread messages appear <strong>bold</strong>. Channels with highlights <strong>flash</strong>.</p>" <>
            "<h4>Toggle</h4>" <>
            "<p>Go to <strong>View &gt; Toggle Treebar</strong> to show or hide it.</p>"
      },
      %{
        id: "ui-tab-bar",
        title: "Tab Bar",
        category: "User Interface",
        keywords: ["tab", "tab bar", "switch", "close tab"],
        content:
          "<h3>Tab Bar</h3>" <>
            "<p>The tab bar at the top of the chat area provides another way to switch between the Status tab, channels, and PMs.</p>" <>
            "<h4>Features</h4>" <>
            "<p>Click a tab to switch. The active tab is highlighted. Tabs show close buttons (×) for channels and PMs. Unread tabs appear bold, and highlighted tabs flash.</p>"
      },
      %{
        id: "ui-nicklist",
        title: "Nicklist",
        category: "User Interface",
        keywords: ["nicklist", "user list", "nick list", "users", "right pane"],
        content:
          "<h3>Nicklist</h3>" <>
            "<p>The nicklist (right pane) shows all users in the current channel, grouped by status.</p>" <>
            "<h4>Groups</h4>" <>
            "<p><strong>Operators (@):</strong> Red, bold. Can manage the channel.<br/>" <>
            "<strong>Voiced (+):</strong> Blue. Can speak in moderated channels.<br/>" <>
            "<strong>Regular:</strong> Default color.</p>" <>
            "<h4>Context Menu</h4>" <>
            "<p>Right-click a nickname to access Query, Whois, Kick, Ban, Mode, Add to Contacts, and Set Nick Color options.</p>" <>
            "<h4>Toggle</h4>" <>
            "<p>Go to <strong>View &gt; Toggle Nicklist</strong> to show or hide it.</p>"
      },
      %{
        id: "ui-topic-bar",
        title: "Topic Bar",
        category: "User Interface",
        keywords: ["topic bar", "channel info", "modes display"],
        content:
          "<h3>Topic Bar</h3>" <>
            "<p>The topic bar appears below the tab bar and shows the current channel name, active modes, and topic text.</p>" <>
            "<p>For PMs, it shows \"Private conversation with &lt;nickname&gt;\". For the Status tab, it shows \"RetroHexChat Status\".</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-topic\">/topic Command</a></p>"
      },
      %{
        id: "ui-context-menu",
        title: "Context Menu",
        category: "User Interface",
        keywords: ["context menu", "right click", "right-click", "popup"],
        content:
          "<h3>Context Menu</h3>" <>
            "<p>Right-click a nickname in the nicklist to open the context menu.</p>" <>
            "<h4>Options</h4>" <>
            "<p><strong>Query:</strong> Open a PM with the user.<br/>" <>
            "<strong>Whois:</strong> Look up user information.<br/>" <>
            "<strong>Kick / Ban:</strong> Moderation (operators only).<br/>" <>
            "<strong>+o / -o / +v / -v:</strong> Mode changes (operators only).<br/>" <>
            "<strong>Add to Contacts:</strong> Save to your address book.<br/>" <>
            "<strong>Set Nick Color:</strong> Override the display color for this nick.</p>"
      },
      %{
        id: "ui-status-tab",
        title: "Status Tab",
        category: "User Interface",
        keywords: ["status", "status tab", "status window", "system messages"],
        content:
          "<h3>Status Tab</h3>" <>
            "<p>The Status tab shows system messages, service responses, and notify list alerts. It is always present and cannot be closed.</p>" <>
            "<p>Click the <strong>Status</strong> tab in the tab bar or treebar to view it.</p>"
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
        content:
          "<h3>Empty States</h3>" <>
            "<p>When a UI container has no content, a friendly placeholder message appears with guidance:</p>" <>
            "<h4>Channel Messages</h4>" <>
            "<p>An empty channel shows a welcome message and tips for getting started.</p>" <>
            "<h4>Nicklist</h4>" <>
            "<p>Shows \"Ninguém aqui\" when you are the only user (or the channel is truly empty).</p>" <>
            "<h4>Treebar</h4>" <>
            "<p>When no channels are joined, shows a hint to use <code>/join</code> and an \"Explorar canais\" button.</p>" <>
            "<h4>URL Catcher</h4>" <>
            "<p>Shows \"Nenhuma URL capturada\" until URLs appear in chat.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Empty state messages disappear automatically when content arrives. The text is not selectable.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"welcome-wizard\">Welcome Wizard</a> · " <>
            "<a href=\"#\" data-help-topic=\"ui-overview\">UI Overview</a></p>"
      }
    ]
  end
end

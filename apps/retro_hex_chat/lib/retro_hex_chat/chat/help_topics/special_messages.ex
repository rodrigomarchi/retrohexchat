defmodule RetroHexChat.Chat.HelpTopics.SpecialMessages do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "cmd-motd",
        title: "/motd",
        category: "Commands",
        keywords: ["motd", "message of the day"],
        content:
          "<h3>/motd</h3>" <>
            "<p>Display the server Message of the Day. The MOTD is shown automatically when you connect.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/motd</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>Any user can view the MOTD. The MOTD appears in the Status tab.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-setmotd\">/setmotd</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-clearmotd\">/clearmotd</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "cmd-setmotd",
        title: "/setmotd",
        category: "Commands",
        keywords: ["setmotd", "motd", "set message of the day", "admin"],
        content:
          "<h3>/setmotd</h3>" <>
            "<p>Set the server Message of the Day. Requires server administrator privileges.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/setmotd &lt;text&gt;</pre>" <>
            "<h4>Parameters</h4>" <>
            "<p><code>text</code> — The MOTD content to display to users on connect.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/setmotd Welcome to RetroHexChat! Please read the rules.</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-motd\">/motd</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-clearmotd\">/clearmotd</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "cmd-clearmotd",
        title: "/clearmotd",
        category: "Commands",
        keywords: ["clearmotd", "motd", "clear message of the day", "admin"],
        content:
          "<h3>/clearmotd</h3>" <>
            "<p>Clear the server Message of the Day. Requires server administrator privileges.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/clearmotd</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>After clearing, new connections will not see any MOTD.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-motd\">/motd</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-setmotd\">/setmotd</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "cmd-setwelcome",
        title: "/setwelcome",
        category: "Commands",
        keywords: ["setwelcome", "welcome", "channel welcome", "greeting"],
        content:
          "<h3>/setwelcome</h3>" <>
            "<p>Set a welcome message for the current channel. Shown once to users when they join.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/setwelcome &lt;message&gt;</pre>" <>
            "<h4>Parameters</h4>" <>
            "<p><code>message</code> — The welcome text to display. Empty message clears the welcome.</p>" <>
            "<h4>Requirements</h4>" <>
            "<p>You must be a channel operator or owner.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>The welcome message is shown once per session (not on rejoin). " <>
            "The user who set the welcome will not see it themselves.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/setwelcome Welcome to #elixir! Please be respectful.</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-clearwelcome\">/clearwelcome</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "cmd-clearwelcome",
        title: "/clearwelcome",
        category: "Commands",
        keywords: ["clearwelcome", "welcome", "clear welcome"],
        content:
          "<h3>/clearwelcome</h3>" <>
            "<p>Clear the welcome message for the current channel.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/clearwelcome</pre>" <>
            "<h4>Requirements</h4>" <>
            "<p>You must be a channel operator or owner.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-setwelcome\">/setwelcome</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "cmd-wallops",
        title: "/wallops",
        category: "Commands",
        keywords: ["wallops", "operator broadcast", "server message"],
        content:
          "<h3>/wallops</h3>" <>
            "<p>Send a message to all users who have +w (wallops) mode enabled.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/wallops &lt;message&gt;</pre>" <>
            "<h4>Requirements</h4>" <>
            "<p>You must be a server operator or administrator.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Only users who have enabled wallops mode (<code>/umode +w</code>) will see the message. " <>
            "Wallops messages appear in the Status tab.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/wallops Server maintenance in 10 minutes</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-umode\">/umode</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-announce\">/announce</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "cmd-announce",
        title: "/announce",
        category: "Commands",
        keywords: ["announce", "announcement", "global", "broadcast", "admin"],
        content:
          "<h3>/announce</h3>" <>
            "<p>Send a global announcement to all connected users. Bypasses ignore lists.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/announce &lt;message&gt;</pre>" <>
            "<h4>Requirements</h4>" <>
            "<p>You must be a server administrator.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Announcements appear in the user's currently active window with distinctive bold styling. " <>
            "They cannot be filtered or ignored.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/announce Server will restart at midnight UTC</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-wallops\">/wallops</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "cmd-umode",
        title: "/umode",
        category: "Commands",
        keywords: ["umode", "user mode", "wallops", "mode"],
        content:
          "<h3>/umode</h3>" <>
            "<p>Set or unset user modes.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/umode &lt;+/-mode&gt;</pre>" <>
            "<h4>Available Modes</h4>" <>
            "<p><code>+w</code> — Receive wallops messages from server operators.<br/>" <>
            "<code>-w</code> — Stop receiving wallops messages.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>User modes are session-scoped and reset on disconnect.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/umode +w\n/umode -w</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-wallops\">/wallops</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-special-messages\">Special Messages</a></p>"
      },
      %{
        id: "feature-special-messages",
        title: "Special Messages",
        category: "Features",
        keywords: [
          "motd",
          "welcome",
          "wallops",
          "announce",
          "announcement",
          "special messages",
          "server messages"
        ],
        content:
          "<h3>Special Messages</h3>" <>
            "<p>RetroHexChat supports several types of special server and channel messages:</p>" <>
            "<h4>Message of the Day (MOTD)</h4>" <>
            "<p>Server administrators can set a MOTD that all users see when they connect. " <>
            "Use <code>/motd</code> to re-read it at any time.</p>" <>
            "<h4>Channel Welcome Messages</h4>" <>
            "<p>Channel operators can set a welcome message shown once to users when they first join. " <>
            "The message is not shown to the user who set it, and not repeated on rejoin within the same session.</p>" <>
            "<h4>Wallops</h4>" <>
            "<p>Server operators can send wallops messages to users who opt in with <code>/umode +w</code>. " <>
            "Wallops appear in the Status tab.</p>" <>
            "<h4>Global Announcements</h4>" <>
            "<p>Server administrators can send announcements that appear in every user's active window. " <>
            "Announcements bypass ignore lists and have distinctive bold styling.</p>" <>
            "<h4>Commands</h4>" <>
            "<p><code>/motd</code> — View the MOTD<br/>" <>
            "<code>/setmotd</code> — Set the MOTD (admin)<br/>" <>
            "<code>/clearmotd</code> — Clear the MOTD (admin)<br/>" <>
            "<code>/setwelcome</code> — Set channel welcome (operator)<br/>" <>
            "<code>/clearwelcome</code> — Clear channel welcome (operator)<br/>" <>
            "<code>/wallops</code> — Send wallops message (operator)<br/>" <>
            "<code>/announce</code> — Send global announcement (admin)<br/>" <>
            "<code>/umode</code> — Set user modes (+w for wallops)</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-motd\">/motd</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-wallops\">/wallops</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-announce\">/announce</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-umode\">/umode</a></p>"
      }
    ]
  end
end

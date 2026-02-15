defmodule RetroHexChat.Chat.HelpTopics.Features do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "feature-notify-list",
        title: "Notify List (Buddy List)",
        category: "Features",
        keywords: ["notify", "buddy", "friend list", "online", "offline", "track"],
        content:
          "<h3>Notify List (Buddy List)</h3>" <>
            "<p>The Notify List tracks when specific users come online or go offline. You receive notifications in the Status tab.</p>" <>
            "<h4>Opening the Notify List</h4>" <>
            "<p>Use the treebar (click \"Notify List\") or the <code>/notify</code> command.</p>" <>
            "<h4>Adding Users</h4>" <>
            "<pre>/notify add &lt;nickname&gt; [note]</pre>" <>
            "<p>Or use the <strong>Add</strong> button in the Notify List window.</p>" <>
            "<h4>Auto-Whois</h4>" <>
            "<p>Enable auto-whois to automatically look up user info when they come online.</p>" <>
            "<h4>Persistence</h4>" <>
            "<p>Register and identify with NickServ to save your notify list across sessions.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-notify\">/notify Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-address-book\">Address Book</a></p>"
      },
      %{
        id: "feature-address-book",
        title: "Address Book",
        category: "Features",
        keywords: ["address book", "contacts", "nick colors", "color override"],
        content:
          "<h3>Address Book</h3>" <>
            "<p>The Address Book (Ctrl+Shift+A) organizes your contacts, notify list, nick color overrides, and future ignore management in one window.</p>" <>
            "<h4>Tabs</h4>" <>
            "<p><strong>Contacts:</strong> Store notes about users with add/edit/remove.<br/>" <>
            "<strong>Notify:</strong> Manage your buddy list (synced with Notify List window).<br/>" <>
            "<strong>Nick Colors:</strong> Override display colors for specific nicks across the UI.<br/>" <>
            "<strong>Control:</strong> Ignore management (coming in a future update).</p>" <>
            "<h4>Opening</h4>" <>
            "<p>Press <strong>Ctrl+Shift+A</strong>, use the toolbar button, or go to <strong>Tools &gt; Address Book</strong>.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-highlight-words\">Highlight Words</a></p>"
      },
      %{
        id: "feature-highlight-words",
        title: "Highlight Words",
        category: "Features",
        keywords: ["highlight", "mention", "alert", "notification", "flash"],
        content:
          "<h3>Highlight Words</h3>" <>
            "<p>RetroHexChat highlights messages that mention your nickname or custom words. Highlighted messages have a colored background and the channel flashes in the treebar and tab bar.</p>" <>
            "<h4>Default Behavior</h4>" <>
            "<p>Your own nickname is always highlighted (case-insensitive, whole-word match).</p>" <>
            "<h4>Custom Words</h4>" <>
            "<p>Open the Highlight Words dialog (<strong>Ctrl+Shift+H</strong> or <strong>Tools &gt; Highlight Words</strong>) to add custom trigger words with optional background colors.</p>" <>
            "<h4>Sound Notifications</h4>" <>
            "<p>A notification sound plays when a highlight match occurs.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-address-book\">Address Book</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
      },
      %{
        id: "feature-url-catcher",
        title: "URL Catcher",
        category: "Features",
        keywords: ["url", "link", "catcher", "preview", "web"],
        content:
          "<h3>URL Catcher</h3>" <>
            "<p>The URL Catcher captures all URLs shared in channels and PMs. URLs in messages are automatically made clickable with link previews.</p>" <>
            "<h4>Opening</h4>" <>
            "<p>Press <strong>Ctrl+Shift+S</strong> or go to <strong>Tools &gt; URL Catcher</strong>.</p>" <>
            "<h4>Features</h4>" <>
            "<p><strong>Clickable Links:</strong> URLs in messages become clickable, opening in a new tab.<br/>" <>
            "<strong>Link Previews:</strong> Page titles are fetched and shown below the URL.<br/>" <>
            "<strong>URL Catcher Window:</strong> Browse all captured URLs, sorted by time. Filter by channel and search by URL text. Double-click to open.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"formatting-overview\">Text Formatting</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-interactive-elements\">Interactive Chat Elements</a></p>"
      },
      %{
        id: "feature-ignore-list",
        title: "Ignore List",
        category: "Features",
        keywords: ["ignore", "block", "silence", "mute", "filter", "hide", "unignore"],
        content:
          "<h3>Ignore List</h3>" <>
            "<p>The Ignore List lets you hide messages from specific users without moderator intervention. " <>
            "Ignored users are not notified — filtering happens entirely on your side.</p>" <>
            "<h4>Opening the Ignore List Dialog</h4>" <>
            "<p>Press <strong>Ctrl+Shift+G</strong> or go to <strong>Tools &gt; Ignore List</strong>.</p>" <>
            "<h4>Features</h4>" <>
            "<p><strong>Per-Type Filtering:</strong> Ignore all content, or just messages, PMs, actions, or invites.<br/>" <>
            "<strong>Timed Ignores:</strong> Set a duration (e.g., 5m, 2h, 1d) — the ignore automatically expires.<br/>" <>
            "<strong>Dialog Management:</strong> View, add, and remove ignores from the visual dialog.<br/>" <>
            "<strong>Context Menu:</strong> Right-click a nickname to quickly Ignore or Unignore.<br/>" <>
            "<strong>Persistence:</strong> Registered users' ignore lists are saved across sessions.</p>" <>
            "<h4>Filtering Rules</h4>" <>
            "<p>User-authored content (messages, PMs, /me actions) is hidden. " <>
            "System messages (joins, parts, kicks) from ignored users remain visible to maintain channel context.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-ignore\">/ignore Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-unignore\">/unignore Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-flood-protection\">Flood Protection</a></p>"
      },
      %{
        id: "feature-channel-central",
        title: "Channel Central",
        category: "Features",
        keywords: [
          "channel central",
          "channel info",
          "channel settings",
          "modes",
          "bans",
          "ban exceptions",
          "invite exceptions",
          "tabs"
        ],
        content:
          "<h3>Channel Central</h3>" <>
            "<p>Channel Central provides a comprehensive tabbed dialog for viewing and managing all channel settings in one place.</p>" <>
            "<h4>Tabs</h4>" <>
            "<p><strong>General:</strong> Channel name, topic, and basic information.<br/>" <>
            "<strong>Modes:</strong> View and toggle channel modes (+m, +i, +t, +k, +l).<br/>" <>
            "<strong>Bans:</strong> View and manage the channel ban list.<br/>" <>
            "<strong>Ban Exceptions:</strong> Manage ban exceptions (+e) that let specific users bypass bans.<br/>" <>
            "<strong>Invite Exceptions:</strong> Manage invite exceptions (+I) that let specific users bypass invite-only mode.</p>" <>
            "<h4>Opening</h4>" <>
            "<p>Double-click a channel in the treebar, or go to <strong>Tools &gt; Channel Central</strong>.</p>" <>
            "<h4>Permissions</h4>" <>
            "<p>Channel operators see editable controls and can modify settings directly. " <>
            "Non-operators see read-only views of the channel configuration.</p>" <>
            "<h4>Real-Time Updates</h4>" <>
            "<p>The dialog updates in real time when other users change channel settings, " <>
            "so you always see the current state.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-mode\">/mode Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-ban\">/ban Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-topic\">/topic Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-ban-exceptions\">Ban Exceptions</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-invite-exceptions\">Invite Exceptions</a></p>"
      },
      %{
        id: "feature-ban-exceptions",
        title: "Ban Exceptions (+e)",
        category: "Features",
        keywords: ["ban exception", "ban exempt", "exception", "exempt", "bypass ban", "+e"],
        content:
          "<h3>Ban Exceptions (+e)</h3>" <>
            "<p>Ban exceptions allow specific users to bypass channel bans. " <>
            "If a user is both banned and has a ban exception, they can still join and participate in the channel.</p>" <>
            "<h4>Managing Ban Exceptions</h4>" <>
            "<p>Ban exceptions are managed through the <strong>Ban Exceptions</strong> tab in " <>
            "<a href=\"#\" data-help-topic=\"feature-channel-central\">Channel Central</a>. " <>
            "Only channel operators can add or remove ban exceptions.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>When a user attempts to join a channel where they are banned, the server checks " <>
            "the ban exception list. If the user matches a ban exception entry, the ban is overridden " <>
            "and they are allowed to join.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-ban\">/ban Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-channel-central\">Channel Central</a></p>"
      },
      %{
        id: "feature-invite-exceptions",
        title: "Invite Exceptions (+I)",
        category: "Features",
        keywords: [
          "invite exception",
          "invite exempt",
          "invite bypass",
          "+I",
          "invite-only bypass"
        ],
        content:
          "<h3>Invite Exceptions (+I)</h3>" <>
            "<p>Invite exceptions allow specific users to bypass invite-only (+i) mode. " <>
            "When a channel has +i mode set, users in the invite exceptions list can still " <>
            "join without an explicit invite from an operator.</p>" <>
            "<h4>Managing Invite Exceptions</h4>" <>
            "<p>Invite exceptions are managed through the <strong>Invite Exceptions</strong> tab in " <>
            "<a href=\"#\" data-help-topic=\"feature-channel-central\">Channel Central</a>. " <>
            "Only channel operators can add or remove invite exceptions.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>When a user attempts to join an invite-only channel, the server checks the " <>
            "invite exception list. If the user matches an invite exception entry, " <>
            "they are allowed to join without needing an invite.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-mode\">/mode Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-channel-central\">Channel Central</a></p>"
      },
      %{
        id: "feature-channel-invites",
        title: "Channel Invites",
        category: "Features",
        keywords: [
          "invite",
          "channel invite",
          "invite dialog",
          "auto-join on invite",
          "invite expiration",
          "invite-only"
        ],
        content:
          "<h3>Channel Invites</h3>" <>
            "<p>The channel invite system allows operators of invite-only (+i) channels to " <>
            "invite specific users to join. Invited users receive a Windows 98-style dialog " <>
            "with Join and Ignore options.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>1. An operator uses <code>/invite &lt;nickname&gt;</code> to invite a user.<br/>" <>
            "2. The invited user sees a popup dialog with the inviter's name and channel.<br/>" <>
            "3. Clicking <strong>Join</strong> joins the channel. Clicking <strong>Ignore</strong> dismisses the dialog.<br/>" <>
            "4. Invitations expire after 5 minutes if not accepted.</p>" <>
            "<h4>Auto-Join on Invite</h4>" <>
            "<p>Users can enable auto-join with <code>/invite auto</code>. When enabled, " <>
            "incoming invitations are accepted automatically without showing a dialog. " <>
            "This is disabled by default for security.</p>" <>
            "<h4>Requirements</h4>" <>
            "<p>Only channel operators can send invites. The channel must have +i (invite-only) " <>
            "mode set. The target user must be online and not already in the channel.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-invite\">/invite Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"mode-i\">+i Invite Only</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-invite-exceptions\">Invite Exceptions</a></p>"
      },
      %{
        id: "feature-search",
        title: "Search",
        category: "Features",
        keywords: [
          "search",
          "find",
          "ctrl+f",
          "text search",
          "highlight",
          "regex",
          "case sensitive",
          "history search"
        ],
        content:
          "<h3>Search</h3>" <>
            "<p>Search through messages in the current channel or PM with real-time highlighting.</p>" <>
            "<h4>Opening</h4>" <>
            "<p>Press <strong>Ctrl+Shift+F</strong> or go to <strong>Edit &gt; Find...</strong>.</p>" <>
            "<h4>Highlighting</h4>" <>
            "<p>As you type, all matching occurrences in the chat are highlighted with a yellow background. " <>
            "The active match is highlighted in orange. The counter shows your position (e.g., \"3 of 17\").</p>" <>
            "<h4>Navigation</h4>" <>
            "<p>Use <strong>Prev</strong>/<strong>Next</strong> buttons, or press " <>
            "<strong>Arrow Down</strong>/<strong>Arrow Up</strong> in the search input to jump between matches. " <>
            "The chat scrolls to each match automatically.</p>" <>
            "<h4>Search Filters</h4>" <>
            "<p><strong>Case:</strong> Case-sensitive matching (default: case-insensitive).<br/>" <>
            "<strong>Regex:</strong> Regular expression matching (e.g., <code>error|warn</code>). " <>
            "Invalid regex patterns show an inline error.<br/>" <>
            "<strong>My nick:</strong> Only search messages that mention your nickname.<br/>" <>
            "<strong>History:</strong> Extend search into the database beyond currently loaded messages.</p>" <>
            "<h4>Session Memory</h4>" <>
            "<p>The search bar remembers your last search term. When you reopen it, " <>
            "the previous query is restored and matches are re-highlighted.</p>" <>
            "<h4>Closing</h4>" <>
            "<p>Press <strong>Escape</strong> or click the close button. All highlights are removed.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-cheatsheet\">Shortcut Cheatsheet</a></p>"
      },
      %{
        id: "feature-log-viewer",
        title: "Log Viewer",
        category: "Features",
        keywords: ["log", "viewer", "search", "history", "browse", "export", "logs"],
        content:
          "<h3>Log Viewer</h3>" <>
            "<p>The Log Viewer lets you search and browse your chat history across channels and private messages.</p>" <>
            "<h4>Opening</h4>" <>
            "<p>Open via <strong>Ctrl+Shift+L</strong>, the <strong>Tools &gt; Log Viewer</strong> menu, or the toolbar button.</p>" <>
            "<h4>Filtering</h4>" <>
            "<p>Use the controls at the top to filter by:</p>" <>
            "<ul><li><strong>Source</strong> — Select a channel or PM partner</li>" <>
            "<li><strong>Date Range</strong> — Set From and To dates</li>" <>
            "<li><strong>Nickname</strong> — Filter by message author (partial match)</li>" <>
            "<li><strong>Text</strong> — Search message content (case-insensitive)</li></ul>" <>
            "<p>Click <strong>Search</strong> to apply filters, or <strong>Refresh</strong> to re-run the current query.</p>" <>
            "<h4>Pagination</h4>" <>
            "<p>Results are paginated (50 per page). Use <strong>Prev</strong> / <strong>Next</strong> buttons to navigate.</p>" <>
            "<h4>Display Options</h4>" <>
            "<p>Toggle visibility of system events (Joins, Parts, Kicks, Modes, Topics) and choose timestamp format.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-log-export\">Log Export</a> · " <>
            "<a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a></p>"
      },
      %{
        id: "feature-log-export",
        title: "Log Export",
        category: "Features",
        keywords: ["export", "download", "txt", "html", "log", "save"],
        content:
          "<h3>Log Export</h3>" <>
            "<p>Export your filtered log results as a downloadable file.</p>" <>
            "<h4>Export Formats</h4>" <>
            "<ul><li><strong>.txt</strong> — Plain text with timestamps, one message per line</li>" <>
            "<li><strong>.html</strong> — Styled HTML with IRC colors and formatting preserved</li></ul>" <>
            "<h4>How to Export</h4>" <>
            "<p>1. Open the <a href=\"#\" data-help-topic=\"feature-log-viewer\">Log Viewer</a> and apply your desired filters.</p>" <>
            "<p>2. Click <strong>Export .txt</strong> or <strong>Export .html</strong> at the bottom of the dialog.</p>" <>
            "<p>3. The file will download automatically with a descriptive filename.</p>" <>
            "<h4>Filename Pattern</h4>" <>
            "<p>Filenames include the source name and date range: <code>general_2026-01-01_to_2026-01-31.txt</code></p>" <>
            "<h4>Notes</h4>" <>
            "<p>Export includes <em>all</em> matching results, not just the current page. Display preferences (event filtering, timestamp format) are applied to the export.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-log-viewer\">Log Viewer</a></p>"
      },
      %{
        id: "feature-perform",
        title: "Perform / Auto-Commands",
        category: "Features",
        keywords: [
          "perform",
          "auto-commands",
          "auto commands",
          "on connect",
          "autojoin",
          "auto-join",
          "perform list",
          "auto execute"
        ],
        content:
          "<h3>Perform / Auto-Commands</h3>" <>
            "<p>The Perform system lets you define commands that execute automatically every time you connect, " <>
            "followed by a list of channels to join.</p>" <>
            "<h4>Perform List</h4>" <>
            "<p>The perform list contains commands (e.g., <code>/ns identify</code>, <code>/mode +x</code>) " <>
            "that run sequentially on connect. Use <code>/perform add &lt;command&gt;</code> to add commands, " <>
            "or manage them visually in the Perform Dialog.</p>" <>
            "<h4>Auto-Join Channels</h4>" <>
            "<p>Auto-join channels are separate from perform commands. They are joined after all perform commands " <>
            "complete, ensuring that NickServ identification and other setup happens first.</p>" <>
            "<h4>Perform Dialog</h4>" <>
            "<p>Press <strong>Ctrl+Shift+E</strong> to open the Perform Dialog, which provides a visual interface " <>
            "for managing both the perform list and auto-join channels.</p>" <>
            "<h4>Enable / Disable</h4>" <>
            "<p>The perform system can be toggled on or off. When disabled, no commands execute and no channels " <>
            "are auto-joined on connect.</p>" <>
            "<h4>Execution Order</h4>" <>
            "<p>1. Perform commands execute sequentially.<br/>" <>
            "2. Auto-join channels are joined after all perform commands complete.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-perform\">/perform Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-autojoin\">/autojoin Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-auto-reconnect\">Auto-Reconnect</a></p>"
      },
      %{
        id: "feature-auto-reconnect",
        title: "Auto-Reconnect",
        category: "Features",
        keywords: [
          "reconnect",
          "auto-reconnect",
          "auto reconnect",
          "disconnect",
          "connection lost",
          "retry",
          "backoff"
        ],
        content:
          "<h3>Auto-Reconnect</h3>" <>
            "<p>RetroHexChat automatically attempts to reconnect when an unexpected disconnection occurs.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>When the connection drops unexpectedly, the client retries with exponential backoff:</p>" <>
            "<pre>Attempt 1:  1 second\nAttempt 2:  2 seconds\nAttempt 3:  4 seconds\nAttempt 4:  8 seconds\nAttempt 5:  16 seconds\nAttempt 6+: 30 seconds (cap)</pre>" <>
            "<p>A maximum of <strong>10 attempts</strong> are made before giving up.</p>" <>
            "<h4>Cancel &amp; Refresh</h4>" <>
            "<p>During reconnection attempts, a <strong>Cancel</strong> button is available to stop retrying. " <>
            "You can also refresh the page to start a fresh connection.</p>" <>
            "<h4>Intentional Disconnect</h4>" <>
            "<p>Auto-reconnect does <strong>not</strong> trigger on intentional disconnects via <code>/quit</code>. " <>
            "It only activates on unexpected connection loss.</p>" <>
            "<h4>Session Restoration</h4>" <>
            "<p>On successful reconnection, your previous session is restored: channels are rejoined " <>
            "and the active tab is restored to its previous state.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-perform\">Perform / Auto-Commands</a></p>"
      },
      %{
        id: "feature-notices",
        title: "Notices",
        category: "Features",
        keywords: ["notice", "notification", "announce", "lightweight message"],
        content:
          "<h3>Notices</h3>" <>
            "<p>Notices are a lightweight message type inspired by IRC's NOTICE command. " <>
            "They are used for announcements, service messages, and bot responses.</p>" <>
            "<h4>Key Characteristics</h4>" <>
            "<p>- Display with <code>-Nick-</code> prefix (distinct from regular &lt;Nick&gt; messages)<br/>" <>
            "- Shown in a distinct color for easy identification<br/>" <>
            "- Do NOT create PM windows or treebar entries<br/>" <>
            "- Do NOT trigger notification sounds or highlights<br/>" <>
            "- The system must NEVER send automatic replies to notices (prevents bot loops)</p>" <>
            "<h4>Sending Notices</h4>" <>
            "<pre>/notice &lt;nickname&gt; &lt;message&gt;\n/notice &lt;#channel&gt; &lt;message&gt;</pre>" <>
            "<h4>Routing Preferences</h4>" <>
            "<p>Use <code>/notice_routing</code> to configure where user-targeted notices appear. " <>
            "Channel notices always appear in the channel window regardless of routing settings.</p>" <>
            "<h4>Ignore Integration</h4>" <>
            "<p>Notices respect the ignore system. Use <code>/ignore &lt;nick&gt; notices</code> " <>
            "to filter notices from a specific user, or <code>/ignore &lt;nick&gt;</code> to filter all message types.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-notice\">/notice Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-notice-routing\">/notice_routing Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"private-messages\">Private Messages</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-ignore\">/ignore Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-ctcp\">CTCP</a></p>"
      },
      %{
        id: "feature-ctcp",
        title: "CTCP (Client-to-Client Protocol)",
        category: "Features",
        keywords: ["ctcp", "ping", "version", "time", "finger", "client-to-client", "latency"],
        content:
          "<h3>CTCP (Client-to-Client Protocol)</h3>" <>
            "<p>CTCP allows users to query information about other users' clients and " <>
            "measure connection latency. Since RetroHexChat is web-based, CTCP is simulated " <>
            "between users within the application.</p>" <>
            "<h4>Available CTCP Types</h4>" <>
            "<p><code>PING</code> — Measures round-trip latency in milliseconds.<br/>" <>
            "<code>VERSION</code> — Returns the target's client version string (default: \"RetroHexChat v1.0\").<br/>" <>
            "<code>TIME</code> — Returns the server's current UTC date and time.<br/>" <>
            "<code>FINGER</code> — Returns the target's profile text or idle time.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/ctcp &lt;nickname&gt; ping\n/ctcp &lt;nickname&gt; version\n/ctcp &lt;nickname&gt; time\n/ctcp &lt;nickname&gt; finger</pre>" <>
            "<h4>Customizing Responses</h4>" <>
            "<p>Access <strong>Tools &gt; CTCP Settings</strong> to:<br/>" <>
            "- Enable or disable CTCP responses entirely<br/>" <>
            "- Set a custom VERSION string<br/>" <>
            "- Set a custom FINGER reply text</p>" <>
            "<h4>Key Behaviors</h4>" <>
            "<p>- CTCP exchanges are private between sender and target<br/>" <>
            "- Self-CTCP returns instant responses (useful for testing)<br/>" <>
            "- Unanswered requests time out after 10 seconds<br/>" <>
            "- Rate limited to 3 requests per target per 30 seconds<br/>" <>
            "- CTCP does NOT create PM windows or treebar entries<br/>" <>
            "- Settings persist for registered (identified) users</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-ctcp\">/ctcp Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notices\">Notices</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-msg\">/msg Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-flood-protection\">Flood Protection</a></p>"
      },
      %{
        id: "feature-flood-protection",
        title: "Flood Protection",
        category: "Features",
        keywords: [
          "flood",
          "spam",
          "duplicate",
          "auto-ignore",
          "protection",
          "anti-spam",
          "rate limit"
        ],
        content:
          "<h3>Flood Protection</h3>" <>
            "<p>Flood Protection automatically detects and handles various types of abuse, " <>
            "including message flooding, duplicate spam, and CTCP request flooding. " <>
            "All detection runs on your side — other users are not affected.</p>" <>
            "<h4>Features</h4>" <>
            "<p><strong>Duplicate Detection:</strong> Detects repeated identical messages from the same sender. " <>
            "Default: 3 identical messages in 10 seconds triggers blocking.<br/>" <>
            "<strong>Auto-Ignore:</strong> Users who exceed the message flood threshold are automatically added " <>
            "to your ignore list for a configurable duration (default: 5 minutes). The ignore is automatically " <>
            "removed when the timer expires.<br/>" <>
            "<strong>CTCP Reply Limiting:</strong> Limits outgoing CTCP replies to prevent your client from " <>
            "being used as a flood amplifier. Default: 2 replies per 10 seconds.<br/>" <>
            "<strong>Cooldown:</strong> If you manually un-ignore an auto-ignored user, a 60-second cooldown " <>
            "prevents the auto-ignore from re-triggering immediately.</p>" <>
            "<h4>Default Thresholds</h4>" <>
            "<pre>Flood Threshold:    10 messages in 15 seconds\n" <>
            "Spam Threshold:      3 duplicates in 10 seconds\n" <>
            "Auto-Ignore Duration: 5 minutes\n" <>
            "CTCP Reply Limit:    2 replies per 10 seconds</pre>" <>
            "<h4>Customizing Settings</h4>" <>
            "<p>Go to <strong>Tools &gt; Flood Protection</strong> to customize all thresholds. " <>
            "Settings persist for registered (identified) users.</p>" <>
            "<h4>Exemptions</h4>" <>
            "<p>- System messages (joins, parts, kicks) are never filtered<br/>" <>
            "- Your own messages do not trigger flood tracking<br/>" <>
            "- Different channels/PM targets are tracked independently</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-ignore-list\">Ignore List</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-ctcp\">CTCP</a></p>"
      },
      %{
        id: "feature-sounds",
        title: "Sounds",
        category: "Features",
        keywords: [
          "sounds",
          "sound",
          "audio",
          "beep",
          "ding",
          "alert",
          "chime",
          "notification sound"
        ],
        content:
          "<h3>Sounds</h3>" <>
            "<p>RetroHexChat plays configurable sounds for various events. Access the " <>
            "Sounds dialog from <strong>Tools &gt; Sounds</strong> to customize which " <>
            "sound plays for each event type.</p>" <>
            "<h4>Event Types</h4>" <>
            "<p><code>Message</code> — New message in a background channel<br/>" <>
            "<code>PM</code> — New private message<br/>" <>
            "<code>Highlight</code> — Your nickname mentioned<br/>" <>
            "<code>Join</code> — User joins a channel<br/>" <>
            "<code>Part</code> — User leaves a channel<br/>" <>
            "<code>Kick</code> — User is kicked from a channel<br/>" <>
            "<code>Connect</code> — You connect to the chat<br/>" <>
            "<code>Disconnect</code> — Connection lost<br/>" <>
            "<code>Buddy Online</code> — A notify list contact comes online<br/>" <>
            "<code>Buddy Offline</code> — A notify list contact goes offline</p>" <>
            "<h4>Sound Catalog</h4>" <>
            "<p>Choose from 14 built-in sounds (ding, alert, chime, click, etc.) " <>
            "or select <code>None</code> to disable sound for an event.</p>" <>
            "<h4>Dialog Controls</h4>" <>
            "<p><strong>OK</strong> — Save changes and close<br/>" <>
            "<strong>Cancel</strong> — Discard changes and close<br/>" <>
            "<strong>Apply</strong> — Save changes and keep dialog open<br/>" <>
            "<strong>Preview</strong> — Play the selected sound</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-mute\">Mute</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-visual-notifications\">Visual Notifications</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
      },
      %{
        id: "feature-mute",
        title: "Mute",
        category: "Features",
        keywords: ["mute", "unmute", "silence", "sound off", "quiet"],
        content:
          "<h3>Mute</h3>" <>
            "<p>The global mute toggle silences all sounds with one click.</p>" <>
            "<h4>Usage</h4>" <>
            "<p>Click <strong>[SND]</strong> in the status bar to mute. " <>
            "The indicator changes to <strong>[MUTE]</strong> when muted. " <>
            "Click again to unmute.</p>" <>
            "<h4>Key Behaviors</h4>" <>
            "<p>- Mute state persists across page reloads (stored in browser)<br/>" <>
            "- Muting does not affect visual notifications (treebar flash, title flash)<br/>" <>
            "- Muting does not affect the typing indicator</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-sounds\">Sounds</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-visual-notifications\">Visual Notifications</a></p>"
      },
      %{
        id: "feature-typing-indicator",
        title: "Typing Indicator",
        category: "Features",
        keywords: ["typing", "indicator", "is typing", "pm typing"],
        content:
          "<h3>Typing Indicator</h3>" <>
            "<p>When someone is typing a message in a PM conversation, " <>
            "a subtle indicator appears showing \"<em>NickName is typing...</em>\".</p>" <>
            "<h4>Key Behaviors</h4>" <>
            "<p>- Only appears in private message conversations (not channels)<br/>" <>
            "- Disappears after 5 seconds of inactivity<br/>" <>
            "- Disappears immediately when the other user sends their message<br/>" <>
            "- Both users can see each other's typing indicators simultaneously<br/>" <>
            "- Ignored users' typing indicators are not shown</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-msg\">/msg Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-ignore-list\">Ignore List</a></p>"
      },
      %{
        id: "feature-visual-notifications",
        title: "Visual Notifications",
        category: "Features",
        keywords: [
          "visual",
          "notifications",
          "flash",
          "blink",
          "treebar",
          "title",
          "activity",
          "indicator"
        ],
        content:
          "<h3>Visual Notifications</h3>" <>
            "<p>When activity occurs in a channel or PM you are not currently viewing, " <>
            "visual indicators alert you.</p>" <>
            "<h4>Treebar Flash</h4>" <>
            "<p>The channel or PM entry in the treebar highlights when new activity " <>
            "arrives. The highlight clears when you switch to that channel or PM.</p>" <>
            "<h4>Title Bar Flash</h4>" <>
            "<p>When the browser tab is not focused, the page title alternates " <>
            "between the normal title and \"* New activity\" to draw your attention.</p>" <>
            "<h4>Per-Event Flash Toggle</h4>" <>
            "<p>In the Sounds dialog (<strong>Tools &gt; Sounds</strong>), each event " <>
            "type has a <strong>Flash</strong> checkbox. Uncheck it to disable visual " <>
            "notifications for that event type while keeping sounds enabled.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-sounds\">Sounds</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-mute\">Mute</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
      },
      %{
        id: "feature-favorites",
        title: "Favorites",
        category: "Features",
        keywords: [
          "favorites",
          "bookmarks",
          "channels",
          "auto-join",
          "autojoin",
          "quick",
          "access"
        ],
        content:
          "<h3>Favorites</h3>" <>
            "<p>Favorites let you bookmark channels for quick access, similar to " <>
            "browser bookmarks. Access them from the <strong>Favorites</strong> " <>
            "menu in the menu bar.</p>" <>
            "<h4>Adding a Favorite</h4>" <>
            "<p>Right-click a channel in the treebar and select " <>
            "<strong>Add to Favorites</strong>. A dialog lets you set:</p>" <>
            "<p>- <strong>Channel name</strong> (pre-filled from the channel)<br/>" <>
            "- <strong>Description</strong> (optional, shown in the Favorites menu)<br/>" <>
            "- <strong>Password</strong> (for +k channels, stored encrypted)<br/>" <>
            "- <strong>Auto-join on connect</strong> (join automatically after identification)</p>" <>
            "<h4>Using Favorites</h4>" <>
            "<p>Click a favorite in the <strong>Favorites</strong> menu to join " <>
            "the channel (or switch to it if already joined). Channels you are " <>
            "currently in are marked with a checkmark.</p>" <>
            "<h4>Auto-Join</h4>" <>
            "<p>Favorites marked with <em>Auto-join on connect</em> are automatically " <>
            "joined after you identify with NickServ. This runs after any " <>
            "Perform auto-join commands.</p>" <>
            "<h4>Duplicate Detection</h4>" <>
            "<p>Adding a channel that is already in your favorites opens the " <>
            "existing entry for editing instead of creating a duplicate.</p>" <>
            "<h4>Persistence</h4>" <>
            "<p>Favorites are saved to the database for registered users. " <>
            "Guest users lose their favorites when they disconnect.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-organize-favorites\">Organize Favorites</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-join\">/join Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-perform\">Perform</a></p>"
      },
      %{
        id: "feature-organize-favorites",
        title: "Organize Favorites",
        category: "Features",
        keywords: [
          "organize",
          "favorites",
          "reorder",
          "edit",
          "remove",
          "manage",
          "bookmarks"
        ],
        content:
          "<h3>Organize Favorites</h3>" <>
            "<p>The Organize Favorites dialog lets you manage your favorites list. " <>
            "Open it from <strong>Favorites &gt; Organize Favorites...</strong>.</p>" <>
            "<h4>Features</h4>" <>
            "<p>- <strong>Reorder</strong>: Select a favorite and use " <>
            "<strong>Move Up</strong> / <strong>Move Down</strong> to change its " <>
            "position in the Favorites menu.<br/>" <>
            "- <strong>Edit</strong>: Modify a favorite's description, password, " <>
            "or auto-join setting.<br/>" <>
            "- <strong>Remove</strong>: Delete a favorite from the list.</p>" <>
            "<h4>Display Columns</h4>" <>
            "<p>The dialog shows each favorite's channel name, description, " <>
            "password status (\"Password set\" if configured), and auto-join " <>
            "setting (\"Yes\" if enabled).</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-favorites\">Favorites</a></p>"
      },
      %{
        id: "feature-aliases",
        title: "Aliases",
        category: "Features",
        keywords: ["alias", "aliases", "shortcut", "macro", "expansion", "scripting"],
        content:
          "<h3>Aliases</h3>" <>
            "<p>Aliases let you create custom command shortcuts. Type a short name and it expands " <>
            "into a longer command or message, with optional variable substitution.</p>" <>
            "<h4>Creating Aliases</h4>" <>
            "<p>Use <code>/alias add &lt;name&gt; &lt;expansion&gt;</code> or open the " <>
            "<strong>Alias Editor</strong> from <strong>Tools &gt; Alias Editor</strong>.</p>" <>
            "<h4>Variable Expansion</h4>" <>
            "<p><code>$1</code>–<code>$9</code> — Positional arguments (words typed after the alias).<br/>" <>
            "<code>$nick</code> — Your current nickname.<br/>" <>
            "<code>$chan</code> — Current channel name.<br/>" <>
            "<code>$$</code> — Literal <code>$</code> character.</p>" <>
            "<h4>Safety Features</h4>" <>
            "<p>- <strong>No command chaining</strong>: Expansions cannot contain <code>|</code>, " <>
            "<code>&amp;&amp;</code>, <code>;</code>, or newlines.<br/>" <>
            "- <strong>Recursion detection</strong>: Alias chains (A → B → A) are caught at 5 levels.<br/>" <>
            "- <strong>Shadowing warning</strong>: Creating an alias that matches a built-in command " <>
            "shows a warning but is allowed.</p>" <>
            "<h4>Limits</h4>" <>
            "<p>Maximum 50 aliases per user. Names: 1–30 characters (alphanumeric, hyphens, underscores). " <>
            "Expansions: up to 500 characters. Persisted for registered users.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-alias\">/alias Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-timers\">Timers</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-custom-menus\">Custom Menus</a></p>"
      },
      %{
        id: "feature-timers",
        title: "Timers",
        category: "Features",
        keywords: ["timer", "timers", "schedule", "delay", "repeat", "interval"],
        content:
          "<h3>Timers</h3>" <>
            "<p>Timers let you schedule commands to run after a delay or on a repeating interval. " <>
            "Useful for periodic reminders, heartbeat messages, or delayed actions.</p>" <>
            "<h4>Timer Types</h4>" <>
            "<p><strong>One-shot</strong>: Runs once after the specified delay.<br/>" <>
            "<code>/timer remind 1800 /me standup in 30 minutes</code></p>" <>
            "<p><strong>Repeating</strong>: Runs every N seconds until stopped.<br/>" <>
            "<code>/timer hb repeat 600 /me is still here</code></p>" <>
            "<h4>Managing Timers</h4>" <>
            "<p><code>/timer list</code> — Show all active timers.<br/>" <>
            "<code>/timer stop &lt;name&gt;</code> — Cancel a specific timer.</p>" <>
            "<h4>Limits</h4>" <>
            "<p>- Maximum 5 concurrent timers per session.<br/>" <>
            "- One-shot: minimum 1 second, maximum 86,400 seconds (24 hours).<br/>" <>
            "- Repeat: minimum 10 seconds, maximum 86,400 seconds.<br/>" <>
            "- <strong>Session-only</strong>: Timers do NOT survive page reload or disconnection.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-timer\">/timer Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-aliases\">Aliases</a></p>"
      },
      %{
        id: "feature-custom-menus",
        title: "Custom Menus",
        category: "Features",
        keywords: [
          "custom menu",
          "popup",
          "context menu",
          "right-click",
          "nicklist menu",
          "channel menu"
        ],
        content:
          "<h3>Custom Menus</h3>" <>
            "<p>Add custom items to the nicklist and channel right-click context menus. " <>
            "Each item executes a command with variable expansion when clicked.</p>" <>
            "<h4>Menu Types</h4>" <>
            "<p><strong>Nicklist</strong>: Items appear when right-clicking a nickname. " <>
            "Use <code>$1</code> for the target nickname.</p>" <>
            "<p><strong>Channel</strong>: Items appear when right-clicking a channel in the treebar. " <>
            "Use <code>$1</code> for the target channel name.</p>" <>
            "<h4>Managing Items</h4>" <>
            "<p>Use <code>/popups</code> or open <strong>Tools &gt; Custom Menus</strong>. " <>
            "Switch between Nicklist and Channel tabs. Each item has a label (display text) " <>
            "and a command (what runs on click).</p>" <>
            "<h4>Variables</h4>" <>
            "<p><code>$1</code> — Target nickname or channel name.<br/>" <>
            "<code>$nick</code> — Your nickname.<br/>" <>
            "<code>$chan</code> — Current channel.</p>" <>
            "<h4>Limits</h4>" <>
            "<p>Maximum 10 custom items per menu type. Labels: up to 50 characters. " <>
            "Commands: up to 500 characters. Custom items append to (not replace) built-in menu items. " <>
            "Persisted for registered users.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-popups\">/popups Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-aliases\">Aliases</a></p>"
      },
      %{
        id: "feature-options-dialog",
        title: "Options Dialog",
        category: "Features",
        keywords: [
          "options",
          "preferences",
          "settings",
          "configure",
          "customize",
          "Ctrl+Shift+O"
        ],
        content:
          "<h3>Options Dialog</h3>" <>
            "<p>The Options dialog (<strong>Ctrl+Shift+O</strong>) is the central hub for all user preferences. " <>
            "It provides a tree-view navigation with 6 settings panels.</p>" <>
            "<h4>Panels</h4>" <>
            "<p><strong>Connect:</strong> Auto-reconnect behavior (enable/disable, retry interval, max retries, timeout).<br/>" <>
            "<strong>IRC Messages:</strong> Configure where whois results, notices, and PMs are displayed.<br/>" <>
            "<strong>Display:</strong> Toggle toolbar, treebar, switchbar, status bar, compact mode, and line shading.<br/>" <>
            "<strong>Fonts:</strong> Customize font family and size for chat messages, input box, nicklist, and treebar.<br/>" <>
            "<strong>Colors:</strong> Customize chat background, text, system, timestamp, and error colors plus nick palette.<br/>" <>
            "<strong>Key Bindings:</strong> View and customize all keyboard shortcuts.</p>" <>
            "<h4>Apply / OK / Cancel</h4>" <>
            "<p><strong>OK</strong> applies changes and closes the dialog. <strong>Apply</strong> applies changes " <>
            "and keeps the dialog open. <strong>Cancel</strong> discards unsaved changes.</p>" <>
            "<h4>Persistence</h4>" <>
            "<p>Registered users' preferences persist across sessions. Guest preferences last for the current session only.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-display-settings\">Display Settings</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-key-bindings\">Key Bindings</a> · " <>
            "<a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a></p>"
      },
      %{
        id: "feature-display-settings",
        title: "Display Settings",
        category: "Features",
        keywords: [
          "display",
          "toolbar",
          "treebar",
          "switchbar",
          "status bar",
          "compact mode",
          "line shading"
        ],
        content:
          "<h3>Display Settings</h3>" <>
            "<p>Customize the visibility and density of the RetroHexChat interface from " <>
            "<strong>Options &gt; Display</strong> (Ctrl+Shift+O).</p>" <>
            "<h4>UI Element Toggles</h4>" <>
            "<p><strong>Show Toolbar:</strong> Toggle the top toolbar with action buttons.<br/>" <>
            "<strong>Show Treebar:</strong> Toggle the left-side channel/PM tree.<br/>" <>
            "<strong>Show Switchbar:</strong> Toggle the tab bar above the chat area.<br/>" <>
            "<strong>Show Status Bar:</strong> Toggle the bottom status bar.</p>" <>
            "<h4>Appearance</h4>" <>
            "<p><strong>Compact Mode:</strong> Reduces padding and margins throughout the UI for a denser layout.<br/>" <>
            "<strong>Line Shading:</strong> Adds subtle alternating row backgrounds in the chat area " <>
            "for easier reading of long conversations.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-options-dialog\">Options Dialog</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-key-bindings\">Key Bindings</a></p>"
      },
      %{
        id: "feature-key-bindings",
        title: "Key Bindings",
        category: "Features",
        keywords: [
          "key bindings",
          "keybindings",
          "keyboard shortcuts",
          "customize shortcuts",
          "rebind",
          "shortcut"
        ],
        content:
          "<h3>Key Bindings</h3>" <>
            "<p>Customize all keyboard shortcuts from <strong>Options &gt; Key Bindings</strong> (Ctrl+Shift+O).</p>" <>
            "<h4>How to Rebind</h4>" <>
            "<p>1. Open Options (Ctrl+Shift+O) and select the <strong>Key Bindings</strong> panel.<br/>" <>
            "2. Click on an action in the list.<br/>" <>
            "3. Press your desired key combination.<br/>" <>
            "4. Click <strong>Apply</strong> or <strong>OK</strong> to save.</p>" <>
            "<h4>Conflict Detection</h4>" <>
            "<p>If the key combination is already assigned to another action, a warning is shown. " <>
            "Browser-reserved shortcuts (Ctrl+W, Ctrl+T, etc.) cannot be assigned.</p>" <>
            "<h4>Reset to Defaults</h4>" <>
            "<p>Click <strong>Reset to Defaults</strong> to restore all original keyboard shortcuts.</p>" <>
            "<h4>Clearing a Binding</h4>" <>
            "<p>Use the clear button next to an action to unbind a shortcut without assigning a new one.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-options-dialog\">Options Dialog</a></p>"
      },
      %{
        id: "feature-autorespond",
        title: "Auto-Respond",
        category: "Features",
        keywords: [
          "auto-respond",
          "autorespond",
          "auto greet",
          "trigger",
          "event",
          "join greet",
          "welcome"
        ],
        content:
          "<h3>Auto-Respond</h3>" <>
            "<p>Auto-respond rules automatically execute commands when specific events occur, " <>
            "such as when a user joins or leaves a channel.</p>" <>
            "<h4>Trigger Events</h4>" <>
            "<p><code>on_join</code> — Fires when a user joins a channel.<br/>" <>
            "<code>on_part</code> — Fires when a user leaves a channel.<br/>" <>
            "<code>on_nick_change</code> — Fires when a user changes their nickname.</p>" <>
            "<h4>Channel Filtering</h4>" <>
            "<p>Each rule can optionally filter by channel. Leave the channel field empty " <>
            "to match all channels, or specify a channel (e.g., <code>#welcome</code>) to " <>
            "only trigger in that channel.</p>" <>
            "<h4>Safety Features</h4>" <>
            "<p>- <strong>Own-action exclusion</strong>: Your own joins/parts/nick changes " <>
            "never trigger your auto-respond rules.<br/>" <>
            "- <strong>Rate limiting</strong>: 60-second cooldown per rule per triggering user " <>
            "to prevent spam.<br/>" <>
            "- <strong>No cascading</strong>: Auto-respond commands are dispatched normally " <>
            "but cannot trigger other auto-respond rules recursively.</p>" <>
            "<h4>Managing Rules</h4>" <>
            "<p>Use <code>/autorespond</code> or open <strong>Tools &gt; Auto-Respond</strong>. " <>
            "Rules can be enabled/disabled individually via the checkbox in the dialog.</p>" <>
            "<h4>Limits</h4>" <>
            "<p>Maximum 10 auto-respond rules per user. Commands: up to 500 characters. " <>
            "Persisted for registered users.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-autorespond\">/autorespond Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-aliases\">Aliases</a></p>"
      },
      %{
        id: "feature-interactive-elements",
        title: "Interactive Chat Elements",
        category: "Features",
        keywords: [
          "interactive",
          "clickable",
          "hover",
          "tooltip",
          "hover card",
          "channel click",
          "nick click",
          "url hover",
          "link preview"
        ],
        content:
          "<h3>Interactive Chat Elements</h3>" <>
            "<p>Chat messages contain interactive elements that respond to hover and click actions. " <>
            "URLs, channel names, and nicknames are all clickable.</p>" <>
            "<h4>URLs</h4>" <>
            "<p>URLs in messages are underlined on hover with a pointer cursor. " <>
            "Hover to see the page title (fetched automatically). " <>
            "Click to open in a new browser tab.</p>" <>
            "<h4>Channel Names</h4>" <>
            "<p>Channel names (e.g., <code>#general</code>) are clickable. " <>
            "Hover to see a tooltip with the channel name, user count, and action hint. " <>
            "Click to join the channel (or switch to it if already joined).</p>" <>
            "<h4>Nicknames</h4>" <>
            "<p>Hover over a nickname in a chat message for 500ms to see a hover card with user info: " <>
            "hostname, online duration, channels, and away status.</p>" <>
            "<p><strong>Single-click:</strong> Inserts <code>Nick: </code> into your input field.<br/>" <>
            "<strong>Double-click:</strong> Opens a private message conversation.<br/>" <>
            "<strong>Right-click:</strong> Opens the context menu (see Context Menus).</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Interactive elements do not trigger during text selection. " <>
            "The nick hover card does not appear for your own nickname. " <>
            "Hover tooltips dismiss when the mouse leaves the viewport.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-context-menus\">Context Menus</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-url-catcher\">URL Catcher</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-join\">/join Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-msg\">/msg Command</a></p>"
      },
      %{
        id: "feature-nick-alignment",
        title: "Nick Column Alignment",
        category: "Features",
        keywords: ["nick", "alignment", "column", "grid", "layout", "readability"],
        content:
          "<h3>Nick Column Alignment</h3>" <>
            "<p>Nicknames in channel messages are rendered in a fixed-width column. " <>
            "Whether the nick is 3 characters or 15, all message text starts at the same horizontal position.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>Messages use a CSS grid layout (<code>chat-msg-grid</code>) with the nick column set to a fixed width. " <>
            "This dramatically improves readability in busy channels.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Action messages (<code>/me</code>), notices, and system messages are not grid-aligned as they use different formatting.</p>"
      },
      %{
        id: "feature-copy",
        title: "Right-Click Copy",
        category: "Features",
        keywords: ["copy", "clipboard", "right-click", "context menu", "select", "text"],
        content:
          "<h3>Right-Click Copy</h3>" <>
            "<p>Select text in the chat area by clicking and dragging. " <>
            "Right-click to see a context menu with <strong>Copy</strong>, or use <kbd>Ctrl+C</kbd>.</p>" <>
            "<h4>Usage</h4>" <>
            "<p>1. Click and drag to select text in the chat area.<br/>" <>
            "2. Right-click and choose <strong>Copy</strong>, or press <kbd>Ctrl+C</kbd>.<br/>" <>
            "3. The selected text is copied to your clipboard as plain text.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>If no text is selected, the Copy option appears disabled. " <>
            "Rich formatting is stripped — only plain text is copied.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-context-menus\">Context Menus</a></p>"
      },
      %{
        id: "feature-paste-dialog",
        title: "Multi-Line Paste Dialog",
        category: "Features",
        keywords: ["paste", "multiline", "flood", "confirmation", "send"],
        content:
          "<h3>Multi-Line Paste Dialog</h3>" <>
            "<p>When you paste text containing multiple lines into the chat input, " <>
            "a confirmation dialog appears before sending.</p>" <>
            "<h4>Dialog Options</h4>" <>
            "<p><strong>Send All</strong> — Sends each line as a separate message.<br/>" <>
            "<strong>Cancel</strong> — Cancels the paste operation.</p>" <>
            "<h4>Flood Warning</h4>" <>
            "<p>Pasting more than 50 lines shows an additional flood warning. " <>
            "This prevents accidentally flooding a channel.</p>"
      },
      %{
        id: "feature-char-counter",
        title: "Character Counter",
        category: "Features",
        keywords: ["character", "counter", "limit", "length", "input"],
        content:
          "<h3>Character Counter</h3>" <>
            "<p>A real-time character counter appears near the input box showing " <>
            "<code>current/maximum</code> (e.g., <code>127/1000</code>).</p>" <>
            "<h4>Color Indicators</h4>" <>
            "<p>The counter changes color as you approach the limit:<br/>" <>
            "<strong>Green</strong> — under 80% used<br/>" <>
            "<strong>Orange</strong> — 80-95% used<br/>" <>
            "<strong>Red</strong> — over 95% used</p>"
      },
      %{
        id: "feature-quit-message",
        title: "Quit Messages",
        category: "Features",
        keywords: ["quit", "disconnect", "message", "goodbye", "leaving"],
        content:
          "<h3>Quit Messages</h3>" <>
            "<p>When you disconnect, a quit message is shown to other users. " <>
            "You can customize this message.</p>" <>
            "<h4>Setting a Quit Message</h4>" <>
            "<p>Use <code>/quit Your message here</code> to disconnect with a custom message, " <>
            "or configure a default quit message in the Options dialog.</p>" <>
            "<h4>Default</h4>" <>
            "<p>If no custom message is set, the default message is \"Leaving\".</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-quit\">/quit Command</a></p>"
      },
      %{
        id: "feature-away-reply",
        title: "Away Auto-Reply",
        category: "Features",
        keywords: ["away", "auto-reply", "automatic", "reply", "pm", "message"],
        content:
          "<h3>Away Auto-Reply</h3>" <>
            "<p>When you are <code>/away</code> and someone sends you a private message, " <>
            "the system automatically replies with your away message.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>1. Set yourself away: <code>/away Gone for lunch</code><br/>" <>
            "2. When someone PMs you, they see: <em>* YourNick is away: Gone for lunch</em><br/>" <>
            "3. The auto-reply is sent only <strong>once per unique sender</strong> until you return.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Auto-replies are NOT sent for notices (per IRC convention). " <>
            "The replied-to set resets when you clear your away status.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-away\">/away Command</a></p>"
      },
      %{
        id: "feature-emoji",
        title: "Emoji Picker",
        category: "Features",
        keywords: ["emoji", "smiley", "picker", "unicode", "emoticon"],
        content:
          "<h3>Emoji Picker</h3>" <>
            "<p>Access a popup emoji picker with 300+ Unicode emojis organized in 8 categories.</p>" <>
            "<h4>Opening the Picker</h4>" <>
            "<p>Click the smiley face button in the formatting toolbar.</p>" <>
            "<h4>Categories</h4>" <>
            "<p>Smileys &amp; Emotion, People &amp; Body, Animals &amp; Nature, Food &amp; Drink, " <>
            "Travel &amp; Places, Activities, Objects, Symbols.</p>" <>
            "<h4>Search</h4>" <>
            "<p>Type in the search box to filter emojis by name or keyword (minimum 2 characters).</p>" <>
            "<h4>Inserting</h4>" <>
            "<p>Click an emoji to insert it at the cursor position in the chat input. " <>
            "The picker closes automatically after selection.</p>" <>
            "<h4>Closing</h4>" <>
            "<p>Click outside the picker, press <kbd>Escape</kbd>, or click the close button.</p>"
      },
      %{
        id: "feature-timestamp-format",
        title: "Timestamp Configuration",
        category: "Features",
        keywords: ["timestamp", "time", "format", "clock", "date"],
        content:
          "<h3>Timestamp Configuration</h3>" <>
            "<p>Configure how timestamps appear in chat messages via the Options dialog.</p>" <>
            "<h4>Available Formats</h4>" <>
            "<p><code>[HH:MM]</code> — Default, shows hours and minutes.<br/>" <>
            "<code>[HH:MM:SS]</code> — Includes seconds.<br/>" <>
            "<code>[DD/MM HH:MM]</code> — Includes date and time.<br/>" <>
            "<code>None</code> — Hides timestamps entirely.</p>" <>
            "<h4>Changing the Format</h4>" <>
            "<p>Open <strong>Tools &gt; Options</strong>, go to the <strong>Display</strong> panel, " <>
            "and select your preferred format from the Timestamps dropdown. Click <strong>Apply</strong>.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Changing the format resets the chat stream. Previous messages are cleared from view.</p>"
      },
      %{
        id: "feature-autocomplete",
        title: "Autocomplete",
        category: "Features",
        keywords: [
          "autocomplete",
          "auto-complete",
          "tab complete",
          "command palette",
          "fuzzy search",
          "nick completion",
          "channel completion"
        ],
        content:
          "<h3>Autocomplete</h3>" <>
            "<p>RetroHexChat provides context-aware autocomplete for commands, nicknames, and channels.</p>" <>
            "<h4>Command Autocomplete</h4>" <>
            "<p>Type <code>/</code> to open the command palette. Commands are grouped by category " <>
            "(Básicos, Canal, Usuário, Configuração, Avançado) with fuzzy search — typing " <>
            "<code>/jo</code> matches both <code>/join</code> and <code>/autojoin</code>. " <>
            "Your 5 most recently used commands appear at the top.</p>" <>
            "<h4>Nick Autocomplete</h4>" <>
            "<p>Type <code>@</code> followed by characters to search nicknames in the current channel. " <>
            "Online users appear before away users. You can also press <strong>Tab</strong> at the " <>
            "start of input to cycle through matching nicknames IRC-style (with <code>: </code> suffix).</p>" <>
            "<h4>Channel Autocomplete</h4>" <>
            "<p>Type <code>#</code> followed by characters to search channels. Joined channels " <>
            "appear first, marked with a checkmark. Secret channels are hidden from non-members.</p>" <>
            "<h4>Argument Completion</h4>" <>
            "<p>After selecting a command like <code>/msg</code> or <code>/join</code>, " <>
            "the system suggests appropriate arguments — nicknames for user commands, " <>
            "channels for channel commands.</p>" <>
            "<h4>Keyboard Navigation</h4>" <>
            "<p><code>↑/↓</code> — Navigate the dropdown.<br/>" <>
            "<code>Tab</code> or <code>Enter</code> — Select the highlighted item.<br/>" <>
            "<code>Escape</code> — Dismiss the dropdown.<br/>" <>
            "<code>Tab</code> (no dropdown) — Cycle through nick matches.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-command-syntax-tooltip\">Command Syntax Tooltip</a> · " <>
            "<a href=\"#\" data-help-topic=\"getting-started\">Getting Started</a></p>"
      },
      %{
        id: "feature-command-syntax-tooltip",
        title: "Command Syntax Tooltip",
        category: "Features",
        keywords: [
          "syntax",
          "tooltip",
          "command help",
          "parameter",
          "hint",
          "inline help",
          "mode helper"
        ],
        content:
          "<h3>Command Syntax Tooltip</h3>" <>
            "<p>When typing a command (e.g., <code>/mode #general +o</code>), a tooltip appears " <>
            "above the input showing the command syntax with the current parameter highlighted in bold.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>1. Type a command followed by a space (e.g., <code>/mode </code>).<br/>" <>
            "2. The tooltip shows the full syntax with parameter names.<br/>" <>
            "3. As you type arguments, the next expected parameter is highlighted.<br/>" <>
            "4. For <code>/mode</code>, available mode flags are listed below the syntax line.</p>" <>
            "<h4>Detail Levels</h4>" <>
            "<p>Configure in <strong>Options &gt; Display &gt; Command Help</strong>:<br/>" <>
            "<strong>Beginner:</strong> Full descriptions, sub-options, context messages, and examples.<br/>" <>
            "<strong>Expert:</strong> Syntax line only — compact and unobtrusive.<br/>" <>
            "<strong>Off:</strong> Disable the tooltip entirely.</p>" <>
            "<h4>Interaction</h4>" <>
            "<p>Press <strong>Escape</strong> to dismiss the tooltip. " <>
            "The tooltip automatically hides when the autocomplete dropdown is open.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-autocomplete\">Autocomplete</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-smart-input\">Smart Input</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-options-dialog\">Options Dialog</a></p>"
      },
      %{
        id: "feature-smart-input",
        title: "Smart Input",
        category: "Features",
        keywords: [
          "smart input",
          "textarea",
          "multiline",
          "placeholder",
          "expand",
          "input box"
        ],
        content:
          "<h3>Smart Input</h3>" <>
            "<p>The chat input provides contextual hints and adapts to your content.</p>" <>
            "<h4>Contextual Placeholder</h4>" <>
            "<p>The placeholder text changes based on your current context:<br/>" <>
            "In a channel: <em>Mensagem para #channel — / para comandos</em><br/>" <>
            "In a PM: <em>Mensagem para NickName — / para comandos</em><br/>" <>
            "In Status: <em>Digite um comando — / para lista</em></p>" <>
            "<h4>Multi-Line Expansion</h4>" <>
            "<p>The input grows vertically as you type or paste multi-line text, " <>
            "up to 5 visible lines. Beyond that, a scrollbar appears. " <>
            "The chat messages area compresses above to make room.</p>" <>
            "<h4>Keyboard</h4>" <>
            "<p><strong>Enter</strong> — Send message.<br/>" <>
            "<strong>Shift+Enter</strong> — Insert a new line.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-enhanced-history\">Enhanced History</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-command-syntax-tooltip\">Command Syntax Tooltip</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-char-counter\">Character Counter</a></p>"
      },
      %{
        id: "feature-cheatsheet",
        title: "Shortcut Cheatsheet",
        category: "Features",
        keywords: [
          "cheatsheet",
          "cheat sheet",
          "shortcut list",
          "keyboard reference",
          "quick reference"
        ],
        content:
          "<h3>Shortcut Cheatsheet</h3>" <>
            "<p>The Shortcut Cheatsheet displays all available keyboard shortcuts organized by category " <>
            "in a read-only 98.css-styled dialog.</p>" <>
            "<h4>Opening</h4>" <>
            "<p>Press <strong>Ctrl+Shift+/</strong> to toggle the cheatsheet dialog.</p>" <>
            "<h4>Categories</h4>" <>
            "<p>Shortcuts are grouped into categories: Navigation, Windows &amp; Dialogs, " <>
            "and Text Formatting. Each category shows a table with Action and Binding columns.</p>" <>
            "<h4>Custom Bindings</h4>" <>
            "<p>The cheatsheet reflects your current key bindings. If you have customized " <>
            "shortcuts in <strong>Options &gt; Key Bindings</strong>, the cheatsheet shows " <>
            "your custom bindings. Unbound actions show an em dash (&mdash;).</p>" <>
            "<h4>Closing</h4>" <>
            "<p>Press <strong>Escape</strong>, <strong>Ctrl+Shift+/</strong>, or click the close button.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-key-bindings\">Key Bindings</a></p>"
      },
      %{
        id: "feature-context-menus",
        title: "Context Menus",
        category: "Features",
        keywords: [
          "context menu",
          "right-click",
          "right click",
          "popup menu",
          "nick menu",
          "url menu",
          "channel menu",
          "message menu",
          "treebar menu",
          "mute channel"
        ],
        content:
          "<h3>Context Menus</h3>" <>
            "<p>Right-click on elements in the chat area and treebar to access context-specific actions.</p>" <>
            "<h4>Nick Menu (Chat Area)</h4>" <>
            "<p>Right-click a nickname in a chat message to see: Private Message, Whois, Copy Nick, " <>
            "Ignore/Unignore, Add to Address Book, Set Nick Color. Channel operators also see: " <>
            "Kick, Ban, Give Voice (+v), Give Op (+o).</p>" <>
            "<h4>URL Menu</h4>" <>
            "<p>Right-click a URL in a chat message to see: Open Link, Copy URL, Save to URL List.</p>" <>
            "<h4>Channel Menu</h4>" <>
            "<p>Right-click a #channel reference in a chat message to see: Join Channel " <>
            "(disabled if already joined), Add to Favorites, Copy Channel Name, Channel Info.</p>" <>
            "<h4>Message Menu</h4>" <>
            "<p>Right-click the general chat area to see: Copy Message, Copy Selected Text, " <>
            "Quote/Reply (disabled), Ignore Sender. If the message contains URLs, " <>
            "Open Link and Copy URL also appear.</p>" <>
            "<h4>Treebar Menu</h4>" <>
            "<p>Right-click a channel in the treebar to see: Mark as Read, Mute/Unmute Channel, " <>
            "Add to Favorites, Copy Name, Leave Channel, Channel Settings.</p>" <>
            "<h4>Keyboard Navigation</h4>" <>
            "<p>Use <strong>Arrow Up/Down</strong> to navigate menu items, " <>
            "<strong>Enter</strong> to select, and <strong>Escape</strong> to close.</p>" <>
            "<h4>Notes</h4>" <>
            "<p>Menus automatically reposition if they would go off-screen. " <>
            "The browser's default right-click menu is preserved in the input field. " <>
            "Self-targeting actions (Kick, Ban, Ignore on yourself) appear disabled.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-custom-menus\">Custom Menus</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-favorites\">Favorites</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-interactive-elements\">Interactive Chat Elements</a> · " <>
            "<a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a></p>"
      },
      %{
        id: "feature-enhanced-history",
        title: "Enhanced History",
        category: "Features",
        keywords: [
          "history",
          "ctrl+up",
          "ctrl+down",
          "ctrl+r",
          "reverse search",
          "draft",
          "persistence",
          "localStorage"
        ],
        content:
          "<h3>Enhanced History</h3>" <>
            "<p>Navigate your command and message history with draft preservation " <>
            "and reverse search. History persists across page reloads.</p>" <>
            "<h4>Draft-Preserving Navigation</h4>" <>
            "<p><strong>Ctrl+Up</strong> — Save current text as draft and show previous history entry.<br/>" <>
            "<strong>Ctrl+Down</strong> — Show next entry, or restore your draft when past the newest entry.<br/>" <>
            "Regular <strong>Up/Down</strong> in an empty input works as before (server-side history).</p>" <>
            "<h4>Reverse Search (Ctrl+R)</h4>" <>
            "<p>Press <strong>Ctrl+R</strong> to open an inline search bar. " <>
            "Type to filter history entries by substring match. " <>
            "Press <strong>Enter</strong> to accept the match, or <strong>Escape</strong> to cancel.</p>" <>
            "<h4>Persistence</h4>" <>
            "<p>The last 100 entries are stored in your browser's localStorage. " <>
            "History survives page reloads and browser restarts.</p>" <>
            "<h4>Privacy</h4>" <>
            "<p>Sensitive commands (<code>/identify</code>, <code>/nickserv</code>, <code>/ns</code>) " <>
            "are never saved to localStorage.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-smart-input\">Smart Input</a> · " <>
            "<a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a></p>"
      },
      %{
        id: "feature-contextual-tips",
        title: "Contextual Tips",
        category: "Features",
        keywords: [
          "tips",
          "dicas",
          "contextual",
          "toast",
          "hint",
          "progressive disclosure",
          "onboarding"
        ],
        content:
          "<h3>Contextual Tips</h3>" <>
            "<p>Contextual tips show helpful hints at the right moment — when you first encounter " <>
            "a feature. Each tip appears at most once.</p>" <>
            "<h4>Tip Triggers</h4>" <>
            "<p><strong>First message:</strong> \"Use ↑ para editar sua última mensagem\"<br/>" <>
            "<strong>First join:</strong> \"Canais que você entra aparecem no painel esquerdo\"<br/>" <>
            "<strong>First PM:</strong> \"PMs aparecem como janelas separadas no treebar\"<br/>" <>
            "<strong>First highlight:</strong> \"Seu nick foi mencionado! Configure alertas em Settings\"<br/>" <>
            "<strong>Idle (30s):</strong> \"Digite /help para ver todos os comandos\"</p>" <>
            "<h4>Disabling Tips</h4>" <>
            "<p>Check \"Não mostrar mais dicas\" on any tip toast to suppress all future tips. " <>
            "You can re-enable tips in <strong>Options &gt; Display &gt; Mostrar dicas contextuais</strong>.</p>" <>
            "<h4>Behavior</h4>" <>
            "<p>Tips queue if multiple triggers fire at once (2-second gap between toasts). " <>
            "Tips do not appear while a dialog is open. Tips auto-dismiss after 8 seconds.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"getting-started\">Getting Started</a> · " <>
            "<a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a></p>"
      },
      %{
        id: "feature-unread-indicators",
        title: "Unread Indicators",
        category: "Features",
        keywords: [
          "unread",
          "badge",
          "indicator",
          "treebar",
          "count",
          "mention",
          "highlight",
          "muted",
          "disconnected"
        ],
        content:
          "<h3>Unread Indicators</h3>" <>
            "<p>The treebar shows visual indicators for channel activity.</p>" <>
            "<h4>Visual States</h4>" <>
            "<ul>" <>
            "<li><strong>Bold text</strong> — channel has unread user messages</li>" <>
            "<li><strong>Numeric badge</strong> — shows count of unread messages (e.g., \"3\")</li>" <>
            "<li><strong>Red dot badge</strong> — your nickname was mentioned</li>" <>
            "<li><strong>Selected background</strong> — currently active channel</li>" <>
            "<li><strong>Grayed out</strong> — channel is muted (no badges shown)</li>" <>
            "<li><strong>⚡ icon + gray</strong> — channel is disconnected</li>" <>
            "</ul>" <>
            "<h4>Behavior</h4>" <>
            "<p>Switching to a channel resets its unread count and badges. " <>
            "System messages (joins, parts, quits) do not increment the count — only user messages and mentions do. " <>
            "Counts above 99 display as \"99+\". " <>
            "Muted channels still track unread counts internally — unmuting reveals accumulated indicators.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-kick-notifications\">Kick Notifications</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-copy-feedback\">Copy Feedback</a></p>"
      },
      %{
        id: "feature-kick-notifications",
        title: "Kick Notifications",
        category: "Features",
        keywords: ["kick", "kicked", "expelled", "dialog", "notification"],
        content:
          "<h3>Kick Notifications</h3>" <>
            "<p>When you are kicked from a channel, a dialog appears with the details.</p>" <>
            "<h4>Dialog Contents</h4>" <>
            "<p>The dialog shows: the channel name, who kicked you, and the reason (if provided). " <>
            "Example: \"Você foi expulso de #general por AdminNick: spam\"</p>" <>
            "<h4>Multiple Kicks</h4>" <>
            "<p>If you are kicked from multiple channels simultaneously, the dialogs queue and display one at a time. " <>
            "Click OK to dismiss each dialog.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-unread-indicators\">Unread Indicators</a></p>"
      },
      %{
        id: "feature-copy-feedback",
        title: "Copy Feedback",
        category: "Features",
        keywords: ["copy", "clipboard", "toast", "copied", "copiado", "settings", "saved"],
        content:
          "<h3>Copy & Settings Feedback</h3>" <>
            "<p>Brief toast notifications confirm copy and settings save operations.</p>" <>
            "<h4>Copy Confirmation</h4>" <>
            "<p>When you copy text from the chat (via context menu or keyboard shortcut), " <>
            "a \"Copiado!\" toast appears briefly at the bottom-right and fades after 2 seconds.</p>" <>
            "<h4>Settings Confirmation</h4>" <>
            "<p>When you save settings (OK or Apply in Options), a \"Configurações salvas\" toast confirms the save.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-unread-indicators\">Unread Indicators</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-contextual-tips\">Contextual Tips</a></p>"
      },
      %{
        id: "feature-status-bar",
        title: "Status Bar",
        category: "Features",
        keywords: ["status bar", "lag", "clock", "connection", "mute", "channel info"],
        content:
          "<h3>Status Bar</h3>" <>
            "<p>The status bar at the bottom of the screen provides real-time information about your connection and current channel.</p>" <>
            "<h4>Three Sections</h4>" <>
            "<p><strong>Left:</strong> Current channel name and user count.<br/>" <>
            "<strong>Center:</strong> Connection state with colored indicator (green = connected, red = disconnected).<br/>" <>
            "<strong>Right:</strong> Lag indicator, local clock, and mute toggle.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-lag-indicator\">Lag Indicator</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-connection-states\">Connection States</a></p>"
      },
      %{
        id: "feature-lag-indicator",
        title: "Lag Indicator",
        category: "Features",
        keywords: ["lag", "latency", "ping", "pong", "network", "delay", "timeout"],
        content:
          "<h3>Lag Indicator</h3>" <>
            "<p>The lag indicator in the status bar shows the round-trip latency between your browser and the server, measured every 30 seconds.</p>" <>
            "<h4>Color Thresholds</h4>" <>
            "<p><strong>Normal (green):</strong> Under 200ms — connection is good.<br/>" <>
            "<strong>Warning (yellow):</strong> 200–499ms — noticeable delay.<br/>" <>
            "<strong>Critical (red):</strong> 500ms or more — significant lag.<br/>" <>
            "<strong>Timeout (?):</strong> No response received — connection may be lost.</p>" <>
            "<h4>How It Works</h4>" <>
            "<p>The client sends a ping to the server every 30 seconds. The server echoes the timestamp back, " <>
            "and the client calculates the round-trip time. If no response arrives within 10 seconds, a timeout is shown.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-status-bar\">Status Bar</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-connection-states\">Connection States</a></p>"
      },
      %{
        id: "feature-connection-states",
        title: "Connection States",
        category: "Features",
        keywords: [
          "connection",
          "connected",
          "disconnected",
          "reconnecting",
          "connecting",
          "banner",
          "overlay"
        ],
        content:
          "<h3>Connection States</h3>" <>
            "<p>The status bar shows four possible connection states with visual indicators.</p>" <>
            "<h4>States</h4>" <>
            "<p><strong>● Connected:</strong> Normal operation — you are connected to the server.<br/>" <>
            "<strong>◌ Connecting:</strong> Initial connection in progress.<br/>" <>
            "<strong>● Disconnected:</strong> Connection lost — shown in red.<br/>" <>
            "<strong>↻ Reconnecting:</strong> Attempting to reconnect automatically.</p>" <>
            "<h4>Connection Banners</h4>" <>
            "<p>For brief disconnections (over 1 second), a red banner appears at the top of the chat area. " <>
            "When reconnected, a green banner shows briefly and fades after 3 seconds. " <>
            "Very brief disconnections (under 1 second) are suppressed to avoid flicker.</p>" <>
            "<h4>Reconnect Overlay</h4>" <>
            "<p>For extended disconnections, a full-screen overlay with countdown and retry appears. " <>
            "The banner hides when the overlay is active to avoid duplication.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-status-bar\">Status Bar</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-lag-indicator\">Lag Indicator</a></p>"
      }
    ]
  end
end

defmodule RetroHexChat.Chat.HelpTopics do
  @moduledoc """
  Static help content for the CHM-style help system.
  All topics are compiled at build time — no database required.
  """

  @type topic :: %{
          id: String.t(),
          title: String.t(),
          category: String.t(),
          keywords: [String.t()],
          content: String.t()
        }

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils
  # Content is stored as regular strings (with escaped quotes) to avoid
  # heredoc indentation warnings in multi-line <pre> blocks.

  @topics [
    # ── Getting Started ──────────────────────────────────────
    %{
      id: "welcome",
      title: "Welcome to RetroHexChat",
      category: "Getting Started",
      keywords: ["welcome", "introduction", "about", "overview"],
      content:
        "<h3>Welcome to RetroHexChat</h3>" <>
          "<p>RetroHexChat is a web-based IRC client with an authentic Windows 98 look and feel. " <>
          "It supports channels, private messages, text formatting, nick services, and much more.</p>" <>
          "<h4>Quick Start</h4>" <>
          "<p>1. Enter a nickname on the connect screen and click <strong>Connect</strong>.</p>" <>
          "<p>2. You will automatically join <strong>#lobby</strong>.</p>" <>
          "<p>3. Type messages in the input box and press <strong>Enter</strong> to send.</p>" <>
          "<p>4. Use <code>/commands</code> for advanced features — type <code>/help</code> to see them all.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"connecting\">Connecting</a> · " <>
          "<a href=\"#\" data-help-topic=\"channels\">Channels</a> · " <>
          "<a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a></p>"
    },
    %{
      id: "connecting",
      title: "Connecting",
      category: "Getting Started",
      keywords: ["connect", "login", "nickname", "join"],
      content:
        "<h3>Connecting</h3>" <>
          "<p>To connect to RetroHexChat, enter a nickname (1–16 characters, letters/numbers/underscores) on the connect screen and click <strong>Connect</strong>.</p>" <>
          "<p>You will automatically join the <strong>#lobby</strong> channel and can begin chatting immediately.</p>" <>
          "<h4>Registering Your Nickname</h4>" <>
          "<p>To protect your nickname, register it with NickServ:</p>" <>
          "<pre>/ns register &lt;password&gt; &lt;email&gt;</pre>" <>
          "<p>On subsequent visits, identify yourself:</p>" <>
          "<pre>/ns identify &lt;password&gt;</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-nick\">Changing Nickname</a> · " <>
          "<a href=\"#\" data-help-topic=\"nickserv\">NickServ Overview</a></p>"
    },
    %{
      id: "channels",
      title: "Channels",
      category: "Getting Started",
      keywords: ["channel", "room", "chat room", "join channel"],
      content:
        "<h3>Channels</h3>" <>
          "<p>Channels are chat rooms where multiple users can talk. Channel names begin with <strong>#</strong>.</p>" <>
          "<h4>Joining a Channel</h4>" <>
          "<pre>/join #channel-name</pre>" <>
          "<h4>Leaving a Channel</h4>" <>
          "<pre>/part [#channel-name]</pre>" <>
          "<p>If no channel is specified, you leave the current channel.</p>" <>
          "<h4>Listing Channels</h4>" <>
          "<pre>/list</pre>" <>
          "<p>Or use the <strong>Channel List</strong> button in the toolbar.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-join\">Join Command</a> · " <>
          "<a href=\"#\" data-help-topic=\"cmd-part\">Part Command</a> · " <>
          "<a href=\"#\" data-help-topic=\"channel-modes-overview\">Channel Modes</a></p>"
    },
    %{
      id: "private-messages",
      title: "Private Messages",
      category: "Getting Started",
      keywords: ["pm", "private message", "direct message", "dm", "whisper", "query"],
      content:
        "<h3>Private Messages</h3>" <>
          "<p>You can send private messages to other users that only the two of you can see.</p>" <>
          "<h4>Starting a Conversation</h4>" <>
          "<pre>/query &lt;nickname&gt;</pre>" <>
          "<p>This opens a PM tab. Alternatively, send a single message:</p>" <>
          "<pre>/msg &lt;nickname&gt; &lt;message&gt;</pre>" <>
          "<h4>Using the Nicklist</h4>" <>
          "<p>Right-click a nickname in the nicklist and select <strong>Query</strong> to open a PM tab.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-msg\">Msg Command</a> · " <>
          "<a href=\"#\" data-help-topic=\"cmd-query\">Query Command</a></p>"
    },
    # ── Commands ─────────────────────────────────────────────
    %{
      id: "cmd-join",
      title: "/join",
      category: "Commands",
      keywords: ["join", "enter", "channel"],
      content:
        "<h3>/join</h3>" <>
          "<p>Join a channel. Creates the channel if it does not exist.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/join &lt;#channel&gt; [key]</pre>" <>
          "<h4>Parameters</h4>" <>
          "<p><code>#channel</code> — Channel name (must start with #).<br/>" <>
          "<code>key</code> — Optional channel key if the channel has mode +k set.</p>" <>
          "<h4>Examples</h4>" <>
          "<pre>/join #elixir\n/join #secret mykey</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-part\">Part</a> · " <>
          "<a href=\"#\" data-help-topic=\"cmd-invite\">/invite</a> · " <>
          "<a href=\"#\" data-help-topic=\"channels\">Channels</a></p>"
    },
    %{
      id: "cmd-part",
      title: "/part",
      category: "Commands",
      keywords: ["part", "leave", "exit", "channel"],
      content:
        "<h3>/part</h3>" <>
          "<p>Leave the current channel or a specified channel.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/part [#channel]</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/part\n/part #elixir</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-join\">Join</a> · " <>
          "<a href=\"#\" data-help-topic=\"channels\">Channels</a></p>"
    },
    %{
      id: "cmd-msg",
      title: "/msg",
      category: "Commands",
      keywords: ["msg", "message", "private", "whisper", "pm"],
      content:
        "<h3>/msg</h3>" <>
          "<p>Send a private message to a user.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/msg &lt;nickname&gt; &lt;message&gt;</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/msg Alice Hey, how are you?</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-query\">Query</a> · " <>
          "<a href=\"#\" data-help-topic=\"private-messages\">Private Messages</a></p>"
    },
    %{
      id: "cmd-query",
      title: "/query",
      category: "Commands",
      keywords: ["query", "pm", "private", "open conversation"],
      content:
        "<h3>/query</h3>" <>
          "<p>Open a private message tab with a user.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/query &lt;nickname&gt;</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/query Alice</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-msg\">Msg</a> · " <>
          "<a href=\"#\" data-help-topic=\"private-messages\">Private Messages</a></p>"
    },
    %{
      id: "cmd-me",
      title: "/me",
      category: "Commands",
      keywords: ["me", "action", "emote", "roleplay"],
      content:
        "<h3>/me</h3>" <>
          "<p>Send an action message (displayed as <em>* YourNick does something</em>).</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/me &lt;action text&gt;</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/me waves hello\n/me is thinking...</pre>"
    },
    %{
      id: "cmd-nick",
      title: "/nick",
      category: "Commands",
      keywords: ["nick", "nickname", "rename", "change name"],
      content:
        "<h3>/nick</h3>" <>
          "<p>Change your nickname.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/nick &lt;new_nickname&gt;</pre>" <>
          "<p>Nicknames must be 1–16 characters: letters, numbers, and underscores.</p>" <>
          "<h4>Examples</h4>" <>
          "<pre>/nick CoolUser42</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"connecting\">Connecting</a> · " <>
          "<a href=\"#\" data-help-topic=\"nickserv\">NickServ</a></p>"
    },
    %{
      id: "cmd-topic",
      title: "/topic",
      category: "Commands",
      keywords: ["topic", "channel topic", "set topic"],
      content:
        "<h3>/topic</h3>" <>
          "<p>View or set the channel topic.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/topic [new topic text]</pre>" <>
          "<p>Without arguments, shows the current topic. With text, sets a new topic.</p>" <>
          "<p>If the channel has mode <strong>+t</strong>, only operators can change the topic.</p>" <>
          "<h4>Examples</h4>" <>
          "<pre>/topic\n/topic Welcome to #elixir!</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"mode-t\">Topic Lock (+t)</a> · " <>
          "<a href=\"#\" data-help-topic=\"ui-topic-bar\">Topic Bar</a></p>"
    },
    %{
      id: "cmd-mode",
      title: "/mode",
      category: "Commands",
      keywords: ["mode", "channel mode", "set mode", "operator"],
      content:
        "<h3>/mode</h3>" <>
          "<p>Set or remove channel modes. Requires operator status.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/mode &lt;+/-mode&gt; [parameter]</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/mode +m\n/mode -m\n/mode +o Alice\n/mode +k secretpass\n/mode +l 25</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"channel-modes-overview\">Channel Modes Overview</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-channel-central\">Channel Central</a></p>"
    },
    %{
      id: "cmd-kick",
      title: "/kick",
      category: "Commands",
      keywords: ["kick", "remove", "eject"],
      content:
        "<h3>/kick</h3>" <>
          "<p>Remove a user from the channel. Requires operator status.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/kick &lt;nickname&gt; [reason]</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/kick Spammer\n/kick Spammer Flooding the channel</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-ban\">Ban</a> · " <>
          "<a href=\"#\" data-help-topic=\"cmd-mode\">Mode</a></p>"
    },
    %{
      id: "cmd-ban",
      title: "/ban",
      category: "Commands",
      keywords: ["ban", "block", "prohibit"],
      content:
        "<h3>/ban</h3>" <>
          "<p>Ban a user from the channel. Requires operator status.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/ban &lt;nickname&gt;</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/ban Spammer</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-kick\">Kick</a> · " <>
          "<a href=\"#\" data-help-topic=\"cmd-mode\">Mode</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-channel-central\">Channel Central</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-ban-exceptions\">Ban Exceptions</a></p>"
    },
    %{
      id: "cmd-whois",
      title: "/whois",
      category: "Commands",
      keywords: ["whois", "info", "user info", "lookup"],
      content:
        "<h3>/whois</h3>" <>
          "<p>Look up information about a user.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/whois &lt;nickname&gt;</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/whois Alice</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
    },
    %{
      id: "cmd-away",
      title: "/away",
      category: "Commands",
      keywords: ["away", "afk", "absent", "back"],
      content:
        "<h3>/away</h3>" <>
          "<p>Mark yourself as away or return from away.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/away [message]</pre>" <>
          "<p>Without a message, clears your away status. With a message, sets you as away.</p>" <>
          "<h4>Examples</h4>" <>
          "<pre>/away Gone for lunch\n/away</pre>"
    },
    %{
      id: "cmd-clear",
      title: "/clear",
      category: "Commands",
      keywords: ["clear", "clean", "wipe", "reset"],
      content:
        "<h3>/clear</h3>" <>
          "<p>Clear all messages from the current chat window.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/clear</pre>"
    },
    %{
      id: "cmd-quit",
      title: "/quit",
      category: "Commands",
      keywords: ["quit", "disconnect", "exit", "logout"],
      content:
        "<h3>/quit</h3>" <>
          "<p>Disconnect from the server and return to the connect screen.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/quit</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"connecting\">Connecting</a></p>"
    },
    %{
      id: "cmd-list",
      title: "/list",
      category: "Commands",
      keywords: ["list", "channels", "channel list", "browse"],
      content:
        "<h3>/list</h3>" <>
          "<p>Open the channel list window showing all available channels.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/list</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"channels\">Channels</a> · " <>
          "<a href=\"#\" data-help-topic=\"cmd-join\">Join</a></p>"
    },
    %{
      id: "cmd-notify",
      title: "/notify",
      category: "Commands",
      keywords: ["notify", "buddy", "friend", "watch"],
      content:
        "<h3>/notify</h3>" <>
          "<p>Manage your notify (buddy) list to track when users come online or go offline.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/notify add &lt;nickname&gt; [note]\n/notify remove &lt;nickname&gt;\n/notify edit &lt;nickname&gt; &lt;note&gt;\n/notify list\n/notify</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/notify add Alice My friend\n/notify remove Bob\n/notify list</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
    },
    %{
      id: "cmd-ns",
      title: "/ns",
      category: "Commands",
      keywords: ["ns", "nickserv", "register", "identify"],
      content:
        "<h3>/ns</h3>" <>
          "<p>Send a command to NickServ (nickname registration service).</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/ns &lt;command&gt; [arguments]</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/ns register mypassword email@example.com\n/ns identify mypassword\n/ns info Alice\n/ns ghost OldNick mypassword\n/ns drop mypassword</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"nickserv\">NickServ Overview</a></p>"
    },
    %{
      id: "cmd-cs",
      title: "/cs",
      category: "Commands",
      keywords: ["cs", "chanserv", "channel service", "register channel"],
      content:
        "<h3>/cs</h3>" <>
          "<p>Send a command to ChanServ (channel registration service).</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/cs &lt;command&gt; [arguments]</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/cs register #mychannel\n/cs access #mychannel add Alice op\n/cs access #mychannel list\n/cs drop #mychannel</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"chanserv\">ChanServ Overview</a></p>"
    },
    %{
      id: "cmd-help",
      title: "/help",
      category: "Commands",
      keywords: ["help", "commands", "usage"],
      content:
        "<h3>/help</h3>" <>
          "<p>Show available commands or get help for a specific command.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/help [command]</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/help\n/help join\n/help mode</pre>" <>
          "<p>You can also press <strong>F1</strong> at any time to open this Help window.</p>"
    },
    %{
      id: "cmd-perform",
      title: "/perform",
      category: "Commands",
      keywords: ["perform", "auto", "on connect", "execute", "autorun"],
      content:
        "<h3>/perform</h3>" <>
          "<p>Manage your perform list — commands that auto-execute when you connect.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/perform [list|add|remove|move|clear] [args]</pre>" <>
          "<h4>Subcommands</h4>" <>
          "<pre>list              — Show all perform commands\n" <>
          "add &lt;command&gt;      — Append a command to the perform list\n" <>
          "remove &lt;position&gt;  — Remove command at the given position\n" <>
          "move &lt;from&gt; &lt;to&gt;   — Reorder a command from one position to another\n" <>
          "clear             — Remove all perform commands</pre>" <>
          "<h4>Notes</h4>" <>
          "<p>Commands execute sequentially on connect when the perform list is enabled. " <>
          "Passwords in <code>/ns identify</code> commands are masked in the list display for security.</p>" <>
          "<h4>Examples</h4>" <>
          "<pre>/perform list\n/perform add /ns identify mypassword\n/perform remove 2\n/perform move 3 1\n/perform clear</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-autojoin\">/autojoin</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-perform\">Perform / Auto-Commands</a></p>"
    },
    %{
      id: "cmd-autojoin",
      title: "/autojoin",
      category: "Commands",
      keywords: ["autojoin", "auto join", "auto-join", "channel", "on connect"],
      content:
        "<h3>/autojoin</h3>" <>
          "<p>Manage your auto-join channel list — channels that are joined automatically after perform commands complete.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/autojoin [list|add|remove|clear] [args]</pre>" <>
          "<h4>Subcommands</h4>" <>
          "<pre>list                    — Show all auto-join channels\n" <>
          "add &lt;#channel&gt; [key]    — Add a channel (with optional key for +k channels)\n" <>
          "remove &lt;#channel&gt;       — Remove a channel from the auto-join list\n" <>
          "clear                   — Remove all auto-join channels</pre>" <>
          "<h4>Notes</h4>" <>
          "<p>Channels are joined automatically after all perform commands complete. " <>
          "This ensures that NickServ identification and other setup happens before joining channels.</p>" <>
          "<h4>Examples</h4>" <>
          "<pre>/autojoin list\n/autojoin add #elixir\n/autojoin add #secret mykey\n/autojoin remove #elixir\n/autojoin clear</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-perform\">/perform</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-perform\">Perform / Auto-Commands</a></p>"
    },
    %{
      id: "cmd-ignore",
      title: "/ignore",
      category: "Commands",
      keywords: ["ignore", "block", "silence", "mute", "filter", "hide"],
      content:
        "<h3>/ignore</h3>" <>
          "<p>Add a user to your ignore list, hiding their messages from your view. " <>
          "The ignored user receives no notification.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/ignore                        — Show your ignore list\n" <>
          "/ignore &lt;nick&gt;                 — Ignore all content from nick\n" <>
          "/ignore &lt;nick&gt; &lt;type&gt;           — Ignore specific type only\n" <>
          "/ignore &lt;nick&gt; &lt;type&gt; &lt;duration&gt; — Timed ignore</pre>" <>
          "<h4>Types</h4>" <>
          "<pre>all      — All messages, PMs, actions (default)\n" <>
          "messages — Channel messages only\n" <>
          "pms      — Private messages only\n" <>
          "actions  — /me actions only\n" <>
          "invites  — Channel invites only</pre>" <>
          "<h4>Duration Format</h4>" <>
          "<pre>5m  — 5 minutes\n2h  — 2 hours\n1d  — 1 day</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/ignore SpamBot\n/ignore AnnoyingGuy pms\n/ignore LoudPerson all 5m</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-unignore\">/unignore</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-ignore-list\">Ignore List</a></p>"
    },
    %{
      id: "cmd-unignore",
      title: "/unignore",
      category: "Commands",
      keywords: ["unignore", "unblock", "unmute", "unsilence"],
      content:
        "<h3>/unignore</h3>" <>
          "<p>Remove a user from your ignore list. Their messages will be visible again.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/unignore &lt;nick&gt;</pre>" <>
          "<h4>Examples</h4>" <>
          "<pre>/unignore SpamBot</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-ignore\">/ignore</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-ignore-list\">Ignore List</a></p>"
    },
    %{
      id: "cmd-invite",
      title: "/invite",
      category: "Commands",
      keywords: ["invite", "invite user", "channel invite", "invite-only", "auto-join"],
      content:
        "<h3>/invite</h3>" <>
          "<p>Invite a user to an invite-only (+i) channel. Only channel operators can send invites.</p>" <>
          "<h4>Syntax</h4>" <>
          "<pre>/invite &lt;nickname&gt; [#channel]\n" <>
          "/invite auto</pre>" <>
          "<h4>Parameters</h4>" <>
          "<p><code>nickname</code> — The user to invite.<br/>" <>
          "<code>#channel</code> — Target channel (defaults to active channel).<br/>" <>
          "<code>auto</code> — Toggle auto-join on invite preference.</p>" <>
          "<h4>Examples</h4>" <>
          "<pre>/invite Alice\n/invite Alice #private\n/invite auto</pre>" <>
          "<h4>Notes</h4>" <>
          "<p>The invited user receives a dialog popup to Join or Ignore the invitation. " <>
          "Invitations expire after 5 minutes. The channel must have +i mode set.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"feature-channel-invites\">Channel Invites</a> · " <>
          "<a href=\"#\" data-help-topic=\"mode-i\">+i Invite Only</a> · " <>
          "<a href=\"#\" data-help-topic=\"cmd-join\">/join</a></p>"
    },
    # ── Services ─────────────────────────────────────────────
    %{
      id: "nickserv",
      title: "NickServ Overview",
      category: "Services",
      keywords: ["nickserv", "register", "identify", "password", "nickname protection"],
      content:
        "<h3>NickServ Overview</h3>" <>
          "<p>NickServ is the nickname registration service. It lets you protect your nickname with a password so nobody else can use it.</p>" <>
          "<h4>Common Commands</h4>" <>
          "<pre>/ns register &lt;password&gt; &lt;email&gt;   — Register your nickname\n" <>
          "/ns identify &lt;password&gt;            — Identify (log in)\n" <>
          "/ns info &lt;nickname&gt;                — Look up registration info\n" <>
          "/ns ghost &lt;nickname&gt; &lt;password&gt;    — Disconnect a ghost session\n" <>
          "/ns drop &lt;password&gt;                — Unregister your nickname</pre>" <>
          "<h4>Why Register?</h4>" <>
          "<p>Registering lets you persist your settings (notify list, contacts, highlight words, nick colors) across sessions.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-ns\">/ns Command</a> · " <>
          "<a href=\"#\" data-help-topic=\"connecting\">Connecting</a></p>"
    },
    %{
      id: "chanserv",
      title: "ChanServ Overview",
      category: "Services",
      keywords: ["chanserv", "channel service", "register channel", "access list"],
      content:
        "<h3>ChanServ Overview</h3>" <>
          "<p>ChanServ is the channel registration service. It lets you register and manage channels with persistent access control.</p>" <>
          "<h4>Common Commands</h4>" <>
          "<pre>/cs register #channel             — Register a channel (must be op)\n" <>
          "/cs access #channel add &lt;nick&gt; &lt;level&gt; — Add user to access list\n" <>
          "/cs access #channel remove &lt;nick&gt;      — Remove from access list\n" <>
          "/cs access #channel list               — View access list\n" <>
          "/cs drop #channel                      — Unregister a channel</pre>" <>
          "<h4>Access Levels</h4>" <>
          "<p><strong>op</strong> — Full operator rights. <strong>voice</strong> — Can speak in moderated (+m) channels.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-cs\">/cs Command</a> · " <>
          "<a href=\"#\" data-help-topic=\"channel-modes-overview\">Channel Modes</a></p>"
    },
    # ── Channel Modes ────────────────────────────────────────
    %{
      id: "channel-modes-overview",
      title: "Channel Modes Overview",
      category: "Channel Modes",
      keywords: ["mode", "channel mode", "moderated", "invite", "topic lock", "key", "limit"],
      content:
        "<h3>Channel Modes Overview</h3>" <>
          "<p>Channel modes control how a channel behaves. Only channel operators can change modes using <code>/mode</code>.</p>" <>
          "<h4>Available Modes</h4>" <>
          "<p><strong>+m</strong> — <a href=\"#\" data-help-topic=\"mode-m\">Moderated</a>: Only operators and voiced users can speak.<br/>" <>
          "<strong>+i</strong> — <a href=\"#\" data-help-topic=\"mode-i\">Invite Only</a>: Users must be invited to join.<br/>" <>
          "<strong>+t</strong> — <a href=\"#\" data-help-topic=\"mode-t\">Topic Lock</a>: Only operators can change the topic.<br/>" <>
          "<strong>+k</strong> — <a href=\"#\" data-help-topic=\"mode-k\">Key</a>: Requires a password to join.<br/>" <>
          "<strong>+l</strong> — <a href=\"#\" data-help-topic=\"mode-l\">User Limit</a>: Limits the number of users.<br/>" <>
          "<strong>+o</strong> — <a href=\"#\" data-help-topic=\"mode-o\">Operator</a>: Grants operator status.<br/>" <>
          "<strong>+v</strong> — <a href=\"#\" data-help-topic=\"mode-v\">Voice</a>: Grants voice in moderated channels.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-mode\">/mode Command</a></p>"
    },
    %{
      id: "mode-m",
      title: "+m Moderated",
      category: "Channel Modes",
      keywords: ["moderated", "mute", "silence"],
      content:
        "<h3>+m Moderated</h3>" <>
          "<p>When a channel is moderated, only operators (+o) and voiced (+v) users can send messages. Regular users can still read but not write.</p>" <>
          "<h4>Usage</h4>" <>
          "<pre>/mode +m    — Enable moderated mode\n/mode -m    — Disable moderated mode\n/mode +v Nick  — Give voice to a user</pre>"
    },
    %{
      id: "mode-i",
      title: "+i Invite Only",
      category: "Channel Modes",
      keywords: ["invite", "invite only", "restricted"],
      content:
        "<h3>+i Invite Only</h3>" <>
          "<p>When invite-only is set, users cannot join unless they are invited by an operator.</p>" <>
          "<h4>Usage</h4>" <>
          "<pre>/mode +i    — Enable invite only\n/mode -i    — Disable invite only</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-invite\">/invite Command</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-channel-invites\">Channel Invites</a> · " <>
          "<a href=\"#\" data-help-topic=\"feature-invite-exceptions\">Invite Exceptions</a></p>"
    },
    %{
      id: "mode-t",
      title: "+t Topic Lock",
      category: "Channel Modes",
      keywords: ["topic lock", "topic", "restrict topic"],
      content:
        "<h3>+t Topic Lock</h3>" <>
          "<p>When topic lock is set, only channel operators can change the topic.</p>" <>
          "<h4>Usage</h4>" <>
          "<pre>/mode +t    — Enable topic lock\n/mode -t    — Disable topic lock</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"cmd-topic\">/topic Command</a></p>"
    },
    %{
      id: "mode-k",
      title: "+k Channel Key",
      category: "Channel Modes",
      keywords: ["key", "password", "channel password"],
      content:
        "<h3>+k Channel Key</h3>" <>
          "<p>Sets a password (key) that users must provide to join the channel.</p>" <>
          "<h4>Usage</h4>" <>
          "<pre>/mode +k secretpass    — Set channel key\n/mode -k               — Remove channel key\n/join #channel secretpass  — Join with key</pre>"
    },
    %{
      id: "mode-l",
      title: "+l User Limit",
      category: "Channel Modes",
      keywords: ["limit", "user limit", "max users", "capacity"],
      content:
        "<h3>+l User Limit</h3>" <>
          "<p>Limits the maximum number of users that can be in the channel.</p>" <>
          "<h4>Usage</h4>" <>
          "<pre>/mode +l 25    — Set limit to 25 users\n/mode -l       — Remove user limit</pre>"
    },
    %{
      id: "mode-o",
      title: "+o Operator",
      category: "Channel Modes",
      keywords: ["operator", "op", "admin", "channel operator"],
      content:
        "<h3>+o Operator</h3>" <>
          "<p>Grants channel operator status to a user. Operators can change modes, kick/ban users, and set the topic.</p>" <>
          "<h4>Usage</h4>" <>
          "<pre>/mode +o Alice    — Give operator to Alice\n/mode -o Alice    — Remove operator from Alice</pre>" <>
          "<p>The channel founder (first user to join) is automatically given operator status.</p>"
    },
    %{
      id: "mode-v",
      title: "+v Voice",
      category: "Channel Modes",
      keywords: ["voice", "speak", "moderated voice"],
      content:
        "<h3>+v Voice</h3>" <>
          "<p>Grants voice to a user, allowing them to speak in moderated (+m) channels.</p>" <>
          "<h4>Usage</h4>" <>
          "<pre>/mode +v Alice    — Give voice to Alice\n/mode -v Alice    — Remove voice from Alice</pre>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"mode-m\">Moderated (+m)</a></p>"
    },
    # ── Text Formatting ──────────────────────────────────────
    %{
      id: "formatting-overview",
      title: "Text Formatting Overview",
      category: "Text Formatting",
      keywords: ["formatting", "bold", "italic", "underline", "color", "strip"],
      content:
        "<h3>Text Formatting Overview</h3>" <>
          "<p>RetroHexChat supports IRC-compatible text formatting with bold, italic, underline, colors, and more.</p>" <>
          "<h4>Methods</h4>" <>
          "<p><strong>Toolbar:</strong> Use the formatting toolbar below the chat area (B, I, U, Color, Strip buttons).</p>" <>
          "<p><strong>Keyboard Shortcuts:</strong></p>" <>
          "<pre>Ctrl+B — Bold\nCtrl+I — Italic\nCtrl+U — Underline\nCtrl+K — Color (opens color picker)\nCtrl+R — Reverse\nCtrl+O — Reset all formatting</pre>" <>
          "<h4>Strip Formatting</h4>" <>
          "<p>Click the <strong>S</strong> button in the formatting toolbar to strip all formatting from incoming messages.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"formatting-colors\">Colors</a></p>"
    },
    %{
      id: "formatting-colors",
      title: "Colors",
      category: "Text Formatting",
      keywords: ["color", "colour", "foreground", "background", "palette"],
      content:
        "<h3>Colors</h3>" <>
          "<p>RetroHexChat supports the standard 16-color IRC palette for both foreground and background text.</p>" <>
          "<h4>Using Colors</h4>" <>
          "<p>Press <strong>Ctrl+K</strong> or click the <strong>Color</strong> button in the formatting toolbar, then select a color from the 4×4 picker grid.</p>" <>
          "<h4>Color Palette</h4>" <>
          "<pre>0  White      8  Yellow\n1  Black      9  Light Green\n2  Navy       10 Teal\n3  Green      11 Cyan\n4  Red        12 Blue\n5  Maroon     13 Magenta\n6  Purple     14 Grey\n7  Orange     15 Light Grey</pre>"
    },
    # ── Features ─────────────────────────────────────────────
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
          "<p>The Address Book (Alt+B) organizes your contacts, notify list, nick color overrides, and future ignore management in one window.</p>" <>
          "<h4>Tabs</h4>" <>
          "<p><strong>Contacts:</strong> Store notes about users with add/edit/remove.<br/>" <>
          "<strong>Notify:</strong> Manage your buddy list (synced with Notify List window).<br/>" <>
          "<strong>Nick Colors:</strong> Override display colors for specific nicks across the UI.<br/>" <>
          "<strong>Control:</strong> Ignore management (coming in a future update).</p>" <>
          "<h4>Opening</h4>" <>
          "<p>Press <strong>Alt+B</strong>, use the toolbar button, or go to <strong>Tools &gt; Address Book</strong>.</p>" <>
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
          "<p>Open the Highlight Words dialog (<strong>Alt+H</strong> or <strong>Tools &gt; Highlight Words</strong>) to add custom trigger words with optional background colors.</p>" <>
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
          "<p>Press <strong>Alt+U</strong> or go to <strong>Tools &gt; URL Catcher</strong>.</p>" <>
          "<h4>Features</h4>" <>
          "<p><strong>Clickable Links:</strong> URLs in messages become clickable, opening in a new tab.<br/>" <>
          "<strong>Link Previews:</strong> Page titles are fetched and shown below the URL.<br/>" <>
          "<strong>URL Catcher Window:</strong> Browse all captured URLs, sorted by time. Filter by channel and search by URL text. Double-click to open.</p>" <>
          "<h4>See Also</h4>" <>
          "<p><a href=\"#\" data-help-topic=\"formatting-overview\">Text Formatting</a></p>"
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
          "<p>Press <strong>Alt+I</strong> or go to <strong>Tools &gt; Ignore List</strong>.</p>" <>
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
          "<a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
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
      keywords: ["invite exception", "invite exempt", "invite bypass", "+I", "invite-only bypass"],
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
      keywords: ["search", "find", "ctrl+f", "text search"],
      content:
        "<h3>Search</h3>" <>
          "<p>Search through messages in the current channel or PM.</p>" <>
          "<h4>Opening</h4>" <>
          "<p>Press <strong>Ctrl+F</strong> or go to <strong>Edit &gt; Find...</strong>.</p>" <>
          "<h4>Usage</h4>" <>
          "<p>Type your search term and press Enter. Use the arrow buttons to navigate between matches. The current match count is displayed. Press <strong>Escape</strong> to close the search bar.</p>"
    },
    # ── User Interface ───────────────────────────────────────
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
      id: "feature-log-viewer",
      title: "Log Viewer",
      category: "Features",
      keywords: ["log", "viewer", "search", "history", "browse", "export", "logs"],
      content:
        "<h3>Log Viewer</h3>" <>
          "<p>The Log Viewer lets you search and browse your chat history across channels and private messages.</p>" <>
          "<h4>Opening</h4>" <>
          "<p>Open via <strong>Alt+L</strong>, the <strong>Tools &gt; Log Viewer</strong> menu, or the toolbar button.</p>" <>
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
          "<p>Press <strong>Alt+P</strong> to open the Perform Dialog, which provides a visual interface " <>
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
    # ── Keyboard Shortcuts ───────────────────────────────────
    %{
      id: "keyboard-shortcuts",
      title: "Keyboard Shortcuts",
      category: "Keyboard Shortcuts",
      keywords: ["keyboard", "shortcuts", "hotkeys", "keybindings", "keys"],
      content:
        "<h3>Keyboard Shortcuts</h3>" <>
          "<h4>Navigation</h4>" <>
          "<pre>F1            — Open Help\nCtrl+F        — Find / Search\nEscape        — Close search bar</pre>" <>
          "<h4>Windows &amp; Dialogs</h4>" <>
          "<pre>Alt+B         — Address Book\nAlt+H         — Highlight Words\nAlt+I         — Ignore List\nAlt+L         — Log Viewer\nAlt+P         — Perform Dialog\nAlt+U         — URL Catcher</pre>" <>
          "<h4>Text Formatting</h4>" <>
          "<pre>Ctrl+B        — Bold\nCtrl+I        — Italic\nCtrl+U        — Underline\nCtrl+K        — Color\nCtrl+R        — Reverse\nCtrl+O        — Reset formatting</pre>" <>
          "<h4>Input</h4>" <>
          "<pre>Enter         — Send message\nUp / Down     — Command history\nTab           — Tab-complete nicknames</pre>"
    }
  ]

  @topic_map Map.new(@topics, &{&1.id, &1})

  @categories [
    "Getting Started",
    "Commands",
    "Services",
    "Channel Modes",
    "Text Formatting",
    "Features",
    "User Interface",
    "Keyboard Shortcuts"
  ]

  @doc "Return all help topics."
  @spec all_topics() :: [topic()]
  def all_topics, do: @topics

  @doc "Look up a single topic by id. Returns nil if not found."
  @spec get_topic(String.t()) :: topic() | nil
  def get_topic(id), do: Map.get(@topic_map, id)

  @doc "Return topics grouped by category, in display order."
  @spec topics_by_category() :: [{String.t(), [topic()]}]
  def topics_by_category do
    Enum.map(@categories, fn cat ->
      {cat, Enum.filter(@topics, &(&1.category == cat))}
    end)
  end

  @doc "Search topics by query (case-insensitive match on title, keywords, content)."
  @spec search(String.t()) :: [topic()]
  def search(query) when byte_size(query) < 2, do: []

  def search(query) do
    q = String.downcase(query)

    Enum.filter(@topics, fn topic ->
      String.contains?(String.downcase(topic.title), q) or
        Enum.any?(topic.keywords, &String.contains?(String.downcase(&1), q)) or
        String.contains?(String.downcase(topic.content), q)
    end)
  end

  @doc "Return a sorted list of {keyword, topic_id} for the index tab."
  @spec all_keywords() :: [{String.t(), String.t()}]
  def all_keywords do
    @topics
    |> Enum.flat_map(fn topic ->
      Enum.map(topic.keywords, &{&1, topic.id})
    end)
    |> Enum.sort_by(&elem(&1, 0))
  end
end

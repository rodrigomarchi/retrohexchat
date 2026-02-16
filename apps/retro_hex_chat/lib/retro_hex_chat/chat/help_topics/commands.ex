defmodule RetroHexChat.Chat.HelpTopics.Commands do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "commands-overview",
        title: "IRC Commands Reference",
        category: "Commands",
        keywords: ["commands", "reference", "list", "help", "overview", "slash"],
        content:
          "<h3>IRC Commands Reference</h3>" <>
            "<p>RetroHexChat supports the following slash commands. " <>
            "Type them in the chat input and press Enter.</p>" <>
            "<h4>Connection &amp; Navigation</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-join\">/join</a> — Join a channel<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-part\">/part</a> — Leave a channel<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-quit\">/quit</a> — Disconnect from chat<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-list\">/list</a> — List available channels</p>" <>
            "<h4>Messaging</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-msg\">/msg</a> — Send a private message<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-query\">/query</a> — Open a PM window<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-me\">/me</a> — Send an action message<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-notice\">/notice</a> — Send a notice</p>" <>
            "<h4>User Management</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-nick\">/nick</a> — Change nickname<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-away\">/away</a> — Set/clear away status<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-whois\">/whois</a> — Look up user info<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-whowas\">/whowas</a> — Look up past user info<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-ignore\">/ignore</a> — Ignore a user<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-unignore\">/unignore</a> — Remove ignore</p>" <>
            "<h4>Channel Management</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-topic\">/topic</a> — View/set channel topic<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-mode\">/mode</a> — Set channel or user modes<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-kick\">/kick</a> — Kick a user<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-ban\">/ban</a> — Ban a user<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-invite\">/invite</a> — Invite a user</p>" <>
            "<h4>Services</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-ns\">/ns</a> — NickServ commands<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-cs\">/cs</a> — ChanServ commands<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-ctcp\">/ctcp</a> — CTCP requests</p>" <>
            "<h4>Customization</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-notify\">/notify</a> — Manage notify list<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-perform\">/perform</a> — Auto-run commands<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-autojoin\">/autojoin</a> — Auto-join channels<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-alias\">/alias</a> — Create command aliases<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-timer\">/timer</a> — Schedule commands<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-autorespond\">/autorespond</a> — Auto-respond rules</p>" <>
            "<h4>Utility</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-clear\">/clear</a> — Clear chat window<br/>" <>
            "<a href=\"#\" data-help-topic=\"cmd-help\">/help</a> — Show help</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"keyboard-shortcuts\">Keyboard Shortcuts</a></p>"
      },
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
            "<p>Change your nickname. A confirmation dialog will appear before the change is applied, " <>
            "since changing your nickname starts a new chat session.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/nick &lt;new_nickname&gt;</pre>" <>
            "<p>Nicknames must be 1–16 characters: letters, numbers, and underscores.</p>" <>
            "<h4>Confirmation</h4>" <>
            "<p>When you use /nick, a dialog will ask you to confirm the change. " <>
            "If the target nickname is registered with NickServ, you will also need to enter the password.</p>" <>
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
        keywords: ["whois", "info", "user info", "lookup", "profile", "idle", "bio"],
        content:
          "<h3>/whois</h3>" <>
            "<p>Look up detailed information about an online user. Also triggered by double-clicking a nickname in the nicklist.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/whois &lt;nickname&gt;</pre>" <>
            "<h4>Information Shown</h4>" <>
            "<p>Channels, shared channels, online time, idle time, registration status, away message (if set), and bio (if set).</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/whois Alice\n/whois YourOwnNick</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>You can /whois yourself. If the user is not online, a 'not online' message is shown. " <>
            "Double-clicking a nick in the nicklist also triggers /whois.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-whowas\">/whowas</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-bio\">/bio</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
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
      %{
        id: "cmd-bio",
        title: "/bio",
        category: "Commands",
        keywords: ["bio", "profile", "about me", "description"],
        content:
          "<h3>/bio</h3>" <>
            "<p>Set, view, or clear your profile bio. Your bio appears in /whois output when other users look you up.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/bio &lt;text&gt;    — Set your bio\n" <>
            "/bio             — View your current bio\n" <>
            "/bio clear       — Clear your bio</pre>" <>
            "<h4>Examples</h4>" <>
            "<pre>/bio Elixir enthusiast from Brazil\n/bio\n/bio clear</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>Maximum 200 characters. Longer text is automatically truncated with a warning. " <>
            "Bios persist across sessions for registered users (via NickServ). " <>
            "Guest bios last only for the current session. " <>
            "If no bio is set, the bio field does not appear in /whois output.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-whois\">/whois</a> · " <>
            "<a href=\"#\" data-help-topic=\"nickserv\">NickServ</a></p>"
      },
      %{
        id: "cmd-whowas",
        title: "/whowas",
        category: "Commands",
        keywords: ["whowas", "recently", "disconnected", "last seen", "offline"],
        content:
          "<h3>/whowas</h3>" <>
            "<p>Look up information about a recently disconnected user.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/whowas &lt;nickname&gt;</pre>" <>
            "<h4>Information Shown</h4>" <>
            "<p>Last seen time, channels they were in, and quit message (if any).</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/whowas Bob</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>Information is cached for up to 1 hour after disconnection. " <>
            "If no record exists, a 'no whowas information available' message is shown. " <>
            "Lookups are case-insensitive.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-whois\">/whois</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notify-list\">Notify List</a></p>"
      },
      %{
        id: "cmd-notice",
        title: "/notice",
        category: "Commands",
        keywords: ["notice", "notification", "announce"],
        content:
          "<h3>/notice</h3>" <>
            "<p>Send a notice to a user or channel. Notices use <code>-Nick-</code> formatting " <>
            "and do not open PM windows.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/notice &lt;target&gt; &lt;message&gt;</pre>" <>
            "<h4>Parameters</h4>" <>
            "<p><code>target</code> — A nickname or #channel.<br/>" <>
            "<code>message</code> — The notice text to send.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/notice Alice Check out #project\n/notice #elixir Server maintenance in 30 minutes</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>Notices are lightweight messages that:<br/>" <>
            "- Do NOT create PM windows or treebar entries<br/>" <>
            "- Do NOT trigger notification sounds or highlights<br/>" <>
            "- Display with <code>-Nick-</code> prefix (distinct from regular &lt;Nick&gt; messages)<br/>" <>
            "- Channel notices always appear in the channel window</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-notice-routing\">/notice_routing</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notices\">Notices</a> · " <>
            "<a href=\"#\" data-help-topic=\"private-messages\">Private Messages</a></p>"
      },
      %{
        id: "cmd-notice-routing",
        title: "/notice_routing",
        category: "Commands",
        keywords: ["notice", "routing", "preference", "setting"],
        content:
          "<h3>/notice_routing</h3>" <>
            "<p>Configure where incoming user-targeted notices appear.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/notice_routing [active|status|sender]</pre>" <>
            "<h4>Options</h4>" <>
            "<p><code>active</code> — Show in the currently active window (default).<br/>" <>
            "<code>status</code> — Show in the Status Window (falls back to active if no Status tab).<br/>" <>
            "<code>sender</code> — Show in the sender's PM window (falls back to active if no PM window open).</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/notice_routing\n/notice_routing status\n/notice_routing sender</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>Without arguments, displays the current routing preference. " <>
            "This setting is persisted for registered (identified) users.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-notice\">/notice</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notices\">Notices</a></p>"
      },
      %{
        id: "cmd-ctcp",
        title: "/ctcp",
        category: "Commands",
        keywords: ["ctcp", "ping", "version", "time", "finger", "client-to-client"],
        content:
          "<h3>/ctcp</h3>" <>
            "<p>Send a CTCP (Client-to-Client Protocol) request to another user.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/ctcp &lt;target&gt; &lt;type&gt;</pre>" <>
            "<h4>Parameters</h4>" <>
            "<p><code>target</code> — The nickname of the user to query.<br/>" <>
            "<code>type</code> — One of: <code>ping</code>, <code>version</code>, <code>time</code>, <code>finger</code>.</p>" <>
            "<h4>CTCP Types</h4>" <>
            "<p><code>ping</code> — Measure round-trip latency in milliseconds.<br/>" <>
            "<code>version</code> — Query the target's client version string.<br/>" <>
            "<code>time</code> — Query the server's current UTC time.<br/>" <>
            "<code>finger</code> — Query the target's profile text or idle time.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/ctcp Alice ping\n/ctcp Bob version\n/ctcp Alice time\n/ctcp Bob finger</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>- CTCP requests are private between sender and target<br/>" <>
            "- Self-CTCP (targeting yourself) returns instant responses<br/>" <>
            "- Requests time out after 10 seconds if the target has CTCP disabled<br/>" <>
            "- Rate limited to 3 requests per target per 30 seconds<br/>" <>
            "- CTCP exchanges do NOT create PM windows or treebar entries</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-ctcp\">CTCP Feature</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-msg\">/msg</a></p>"
      },
      %{
        id: "cmd-alias",
        title: "/alias",
        category: "Commands",
        keywords: ["alias", "shortcut", "macro", "expansion", "abbreviation"],
        content:
          "<h3>/alias</h3>" <>
            "<p>Create command shortcuts that expand into longer commands or messages.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/alias\n/alias list\n/alias add &lt;name&gt; &lt;expansion&gt;\n/alias remove &lt;name&gt;</pre>" <>
            "<h4>Parameters</h4>" <>
            "<p><code>name</code> — Short name for the alias (letters, numbers, hyphens, underscores).<br/>" <>
            "<code>expansion</code> — Command or text to expand to. Supports variables.</p>" <>
            "<h4>Variables</h4>" <>
            "<p><code>$1</code> through <code>$9</code> — Positional arguments passed after the alias.<br/>" <>
            "<code>$nick</code> — Your current nickname.<br/>" <>
            "<code>$chan</code> — Current channel name.<br/>" <>
            "<code>$$</code> — Literal dollar sign.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/alias add hi /me says hello everyone!\n/alias add greet /me waves at $1\n/alias remove hi\n/alias list</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>- Type <code>/aliasname</code> to invoke (e.g., <code>/hi</code>, <code>/greet Alice</code>).<br/>" <>
            "- Aliases that shadow built-in commands will override them (with a warning).<br/>" <>
            "- Recursive aliases (A → B → A) are detected and rejected (max 5 levels).<br/>" <>
            "- Command chaining (<code>|</code>, <code>&amp;&amp;</code>, <code>;</code>) is not allowed in expansions.<br/>" <>
            "- Maximum 50 aliases per user. Persisted for registered users.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-aliases\">Aliases Feature</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-timer\">/timer</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-popups\">/popups</a></p>"
      },
      %{
        id: "cmd-timer",
        title: "/timer",
        category: "Commands",
        keywords: ["timer", "schedule", "delay", "repeat", "interval", "cron"],
        content:
          "<h3>/timer</h3>" <>
            "<p>Schedule commands to run after a delay or on a repeating interval.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/timer &lt;name&gt; &lt;seconds&gt; &lt;command&gt;\n/timer &lt;name&gt; repeat &lt;seconds&gt; &lt;command&gt;\n/timer list\n/timer stop &lt;name&gt;</pre>" <>
            "<h4>Parameters</h4>" <>
            "<p><code>name</code> — Unique name for the timer (letters, numbers, hyphens, underscores).<br/>" <>
            "<code>seconds</code> — Delay in seconds (1–86400 for one-shot, 10–86400 for repeat).<br/>" <>
            "<code>command</code> — Command to execute when the timer fires.</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/timer remind 1800 /me standup in 30 minutes\n/timer heartbeat repeat 600 /me is still here\n/timer list\n/timer stop heartbeat</pre>" <>
            "<h4>Notes</h4>" <>
            "<p>- Timers are <strong>session-only</strong> — they do not survive page reload.<br/>" <>
            "- Maximum 5 concurrent timers per session.<br/>" <>
            "- Repeat timers have a minimum interval of 10 seconds.<br/>" <>
            "- Timer commands support alias expansion (variables like <code>$nick</code>, <code>$chan</code>).<br/>" <>
            "- Creating a timer with an existing name replaces the old timer.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-timers\">Timers Feature</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-alias\">/alias</a></p>"
      },
      %{
        id: "cmd-popups",
        title: "/popups",
        category: "Commands",
        keywords: ["popups", "popup", "context menu", "custom menu", "right-click"],
        content:
          "<h3>/popups</h3>" <>
            "<p>Open the Custom Menus dialog to manage right-click context menu items.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/popups</pre>" <>
            "<h4>Usage</h4>" <>
            "<p>Opens the Custom Menus dialog where you can add, edit, and remove custom items " <>
            "that appear in the nicklist and channel context menus.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-custom-menus\">Custom Menus Feature</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-alias\">/alias</a></p>"
      },
      %{
        id: "cmd-autorespond",
        title: "/autorespond",
        category: "Commands",
        keywords: ["autorespond", "auto", "respond", "trigger", "event", "greet"],
        content:
          "<h3>/autorespond</h3>" <>
            "<p>Manage event-triggered auto-respond rules.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/autorespond\n/autorespond list\n/autorespond add &lt;trigger&gt; [#channel] &lt;command&gt;\n/autorespond remove &lt;position&gt;</pre>" <>
            "<h4>Parameters</h4>" <>
            "<p><code>trigger</code> — Event type: <code>on_join</code>, <code>on_part</code>, or <code>on_nick_change</code>.<br/>" <>
            "<code>#channel</code> — Optional channel filter (omit to match all channels).<br/>" <>
            "<code>command</code> — Command to execute when the event fires.<br/>" <>
            "<code>position</code> — Rule position number (shown in <code>/autorespond list</code>).</p>" <>
            "<h4>Examples</h4>" <>
            "<pre>/autorespond add on_join #welcome /notice $nick Welcome!\n/autorespond add on_part /say $nick left\n/autorespond list\n/autorespond remove 0</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-autorespond\">Auto-Respond Feature</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-alias\">/alias</a></p>"
      }
    ]
  end
end

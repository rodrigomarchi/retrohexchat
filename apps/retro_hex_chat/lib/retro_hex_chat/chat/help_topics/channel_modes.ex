defmodule RetroHexChat.Chat.HelpTopics.ChannelModes do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
      %{
        id: "channel-modes-overview",
        title: "Channel Modes Overview",
        category: "Channel Modes",
        keywords: [
          "mode",
          "channel mode",
          "moderated",
          "invite",
          "topic lock",
          "key",
          "limit",
          "owner",
          "half-op",
          "secret",
          "private",
          "no external",
          "strip colors",
          "registered",
          "knock",
          "throttle"
        ],
        content:
          "<h3>Channel Modes Overview</h3>" <>
            "<p>Channel modes control how a channel behaves. Only channel operators (or owners) can change modes using <code>/mode</code>.</p>" <>
            "<h4>User Modes</h4>" <>
            "<p><strong>+q</strong> — <a href=\"#\" data-help-topic=\"mode-q\">Owner</a>: Channel owner with full control (~).<br/>" <>
            "<strong>+o</strong> — <a href=\"#\" data-help-topic=\"mode-o\">Operator</a>: Channel operator (@).<br/>" <>
            "<strong>+h</strong> — <a href=\"#\" data-help-topic=\"mode-h\">Half-Operator</a>: Limited operator (%).<br/>" <>
            "<strong>+v</strong> — <a href=\"#\" data-help-topic=\"mode-v\">Voice</a>: Can speak in moderated channels (+).</p>" <>
            "<h4>Channel Modes</h4>" <>
            "<p><strong>+m</strong> — <a href=\"#\" data-help-topic=\"mode-m\">Moderated</a>: Only operators and voiced users can speak.<br/>" <>
            "<strong>+i</strong> — <a href=\"#\" data-help-topic=\"mode-i\">Invite Only</a>: Users must be invited to join.<br/>" <>
            "<strong>+t</strong> — <a href=\"#\" data-help-topic=\"mode-t\">Topic Lock</a>: Only operators can change the topic.<br/>" <>
            "<strong>+k</strong> — <a href=\"#\" data-help-topic=\"mode-k\">Key</a>: Requires a password to join.<br/>" <>
            "<strong>+l</strong> — <a href=\"#\" data-help-topic=\"mode-l\">User Limit</a>: Limits the number of users.<br/>" <>
            "<strong>+n</strong> — <a href=\"#\" data-help-topic=\"mode-n\">No External</a>: Only members can send messages.<br/>" <>
            "<strong>+s</strong> — <a href=\"#\" data-help-topic=\"mode-s\">Secret</a>: Channel hidden from /list and /whois.<br/>" <>
            "<strong>+p</strong> — <a href=\"#\" data-help-topic=\"mode-p\">Private</a>: Channel shown as \"Prv\" in /list.<br/>" <>
            "<strong>+c</strong> — <a href=\"#\" data-help-topic=\"mode-c\">Strip Colors</a>: Remove formatting from messages.<br/>" <>
            "<strong>+R</strong> — <a href=\"#\" data-help-topic=\"mode-R\">Registered Only</a>: Only registered users can join.<br/>" <>
            "<strong>+K</strong> — <a href=\"#\" data-help-topic=\"mode-K\">No Knock</a>: Disable /knock requests.<br/>" <>
            "<strong>+j</strong> — <a href=\"#\" data-help-topic=\"mode-j\">Join Throttle</a>: Limit join rate.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-mode\">/mode Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-knock\">/knock Command</a></p>"
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
        id: "mode-q",
        title: "+q Owner",
        category: "Channel Modes",
        keywords: ["owner", "channel owner", "founder", "tilde"],
        content:
          "<h3>+q Owner</h3>" <>
            "<p>Grants channel owner status to a user (prefix ~). Owners have the highest privilege level and can set any mode, including +o and +q. The first user to join an unregistered channel is automatically made owner.</p>" <>
            "<h4>Hierarchy</h4>" <>
            "<p>Owner (~) > Operator (@) > Half-Operator (%) > Voice (+) > Regular</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +q Alice    — Make Alice an owner\n/mode -q Alice    — Remove owner from Alice</pre>" <>
            "<p>Only other owners can grant or revoke +q.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"mode-o\">Operator (+o)</a> · " <>
            "<a href=\"#\" data-help-topic=\"mode-h\">Half-Operator (+h)</a></p>"
      },
      %{
        id: "mode-o",
        title: "+o Operator",
        category: "Channel Modes",
        keywords: ["operator", "op", "admin", "channel operator"],
        content:
          "<h3>+o Operator</h3>" <>
            "<p>Grants channel operator status to a user (prefix @). Operators can change channel modes, kick/ban users, and set the topic. They cannot kick owners.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +o Alice    — Give operator to Alice\n/mode -o Alice    — Remove operator from Alice</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"mode-q\">Owner (+q)</a> · " <>
            "<a href=\"#\" data-help-topic=\"mode-h\">Half-Operator (+h)</a></p>"
      },
      %{
        id: "mode-h",
        title: "+h Half-Operator",
        category: "Channel Modes",
        keywords: ["half-operator", "halfop", "half op", "helper"],
        content:
          "<h3>+h Half-Operator</h3>" <>
            "<p>Grants half-operator status to a user (prefix %). Half-operators can kick users of lower rank and grant/revoke voice (+v), but cannot set channel modes or ban users.</p>" <>
            "<h4>Permissions</h4>" <>
            "<p>Can: kick regular/voiced users, set +v/-v<br/>" <>
            "Cannot: set channel modes, ban users, kick operators or owners</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +h Alice    — Make Alice a half-operator\n/mode -h Alice    — Remove half-operator from Alice</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"mode-q\">Owner (+q)</a> · " <>
            "<a href=\"#\" data-help-topic=\"mode-o\">Operator (+o)</a></p>"
      },
      %{
        id: "mode-v",
        title: "+v Voice",
        category: "Channel Modes",
        keywords: ["voice", "speak", "moderated voice"],
        content:
          "<h3>+v Voice</h3>" <>
            "<p>Grants voice to a user (prefix +), allowing them to speak in moderated (+m) channels. Half-operators and above can grant voice.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +v Alice    — Give voice to Alice\n/mode -v Alice    — Remove voice from Alice</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"mode-m\">Moderated (+m)</a> · " <>
            "<a href=\"#\" data-help-topic=\"mode-h\">Half-Operator (+h)</a></p>"
      },
      %{
        id: "mode-n",
        title: "+n No External Messages",
        category: "Channel Modes",
        keywords: ["no external", "external messages", "members only"],
        content:
          "<h3>+n No External Messages</h3>" <>
            "<p>When set, only channel members can send messages to the channel. Non-members attempting to send will receive an error. Service messages (NickServ, ChanServ) are not affected.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +n    — Enable no external messages\n/mode -n    — Disable no external messages</pre>"
      },
      %{
        id: "mode-s",
        title: "+s Secret",
        category: "Channel Modes",
        keywords: ["secret", "hidden", "invisible"],
        content:
          "<h3>+s Secret</h3>" <>
            "<p>Makes the channel secret. Secret channels do not appear in the channel list (/list) for non-members and are hidden from /whois output. Mutually exclusive with +p (private).</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +s    — Make channel secret\n/mode -s    — Remove secret mode</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"mode-p\">Private (+p)</a></p>"
      },
      %{
        id: "mode-p",
        title: "+p Private",
        category: "Channel Modes",
        keywords: ["private", "prv", "hidden name"],
        content:
          "<h3>+p Private</h3>" <>
            "<p>Makes the channel private. Private channels appear in the channel list but with the name shown as \"Prv\" to non-members, hiding the actual channel name. Mutually exclusive with +s (secret).</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +p    — Make channel private\n/mode -p    — Remove private mode</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"mode-s\">Secret (+s)</a></p>"
      },
      %{
        id: "mode-c",
        title: "+c Strip Colors",
        category: "Channel Modes",
        keywords: ["strip colors", "no colors", "plain text", "formatting"],
        content:
          "<h3>+c Strip Colors</h3>" <>
            "<p>Strips all formatting codes from messages, including bold, italic, underline, color codes, and reverse. Messages and /me actions are processed server-side before delivery.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +c    — Enable color stripping\n/mode -c    — Disable color stripping</pre>"
      },
      %{
        id: "mode-R",
        title: "+R Registered Only",
        category: "Channel Modes",
        keywords: ["registered only", "identified", "nickserv", "auth"],
        content:
          "<h3>+R Registered Only</h3>" <>
            "<p>When set, only users who have identified with NickServ can join the channel. Users already in the channel when +R is set are not affected.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +R    — Enable registered-only mode\n/mode -R    — Disable registered-only mode</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"feature-nickserv\">NickServ</a></p>"
      },
      %{
        id: "mode-K",
        title: "+K No Knock",
        category: "Channel Modes",
        keywords: ["no knock", "disable knock", "block knock"],
        content:
          "<h3>+K No Knock</h3>" <>
            "<p>Disables the /knock command for the channel. Users will not be able to send knock requests to the channel while this mode is active.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +K    — Disable knocking\n/mode -K    — Allow knocking</pre>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"cmd-knock\">/knock Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"mode-i\">Invite Only (+i)</a></p>"
      },
      %{
        id: "mode-j",
        title: "+j Join Throttle",
        category: "Channel Modes",
        keywords: ["join throttle", "rate limit", "flood", "join limit"],
        content:
          "<h3>+j Join Throttle</h3>" <>
            "<p>Limits how many users can join the channel within a time window. Format is count:seconds. For example, +j 5:10 allows 5 joins per 10 seconds. Operators bypass the throttle.</p>" <>
            "<h4>Usage</h4>" <>
            "<pre>/mode +j 5:10    — Allow 5 joins per 10 seconds\n/mode +j 3:60    — Allow 3 joins per minute\n/mode -j         — Remove join throttle</pre>"
      },
      %{
        id: "cmd-knock",
        title: "/knock Command",
        category: "Commands",
        keywords: ["knock", "request invite", "join request"],
        content:
          "<h3>/knock Command</h3>" <>
            "<p>Sends a knock request to an invite-only (+i) channel. Channel operators and owners will see your knock notification and can choose to invite you.</p>" <>
            "<h4>Syntax</h4>" <>
            "<pre>/knock #channel [message]</pre>" <>
            "<h4>Examples</h4>" <>
            "<pre>/knock #private\n/knock #private Hey, can I join? Referred by Alice.</pre>" <>
            "<h4>Requirements</h4>" <>
            "<p>The channel must be invite-only (+i). Knocking is disabled if +K is set. You cannot knock if you are banned or already a member. Rate limited to once per 60 seconds per channel.</p>" <>
            "<h4>See Also</h4>" <>
            "<p><a href=\"#\" data-help-topic=\"mode-i\">Invite Only (+i)</a> · " <>
            "<a href=\"#\" data-help-topic=\"mode-K\">No Knock (+K)</a> · " <>
            "<a href=\"#\" data-help-topic=\"cmd-invite\">/invite Command</a></p>"
      }
    ]
  end
end

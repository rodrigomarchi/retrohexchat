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
      }
    ]
  end
end

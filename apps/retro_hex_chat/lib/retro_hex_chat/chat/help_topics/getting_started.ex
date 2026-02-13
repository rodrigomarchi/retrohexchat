defmodule RetroHexChat.Chat.HelpTopics.GettingStarted do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
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
            "<a href=\"#\" data-help-topic=\"cmd-query\">Query Command</a> · " <>
            "<a href=\"#\" data-help-topic=\"feature-notices\">Notices</a></p>"
      }
    ]
  end
end

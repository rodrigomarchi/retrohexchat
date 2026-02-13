defmodule RetroHexChat.Chat.HelpTopics.Services do
  @moduledoc false

  # credo:disable-for-this-file Credo.Check.Readability.StringSigils

  @spec topics() :: [map()]
  def topics do
    [
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
      }
    ]
  end
end

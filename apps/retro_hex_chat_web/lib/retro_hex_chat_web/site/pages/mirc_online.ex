defmodule RetroHexChatWeb.Site.Pages.MircOnline do
  @moduledoc """
  The page for someone looking for mIRC online: what of mIRC carries over to
  a chat in the browser, and — said plainly, before they find out — what does
  not. It is not mIRC and not an IRC server, and the page says so.
  """
  use RetroHexChatWeb.Site.Page

  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Pages.Guides

  @questions [
    {dgettext_noop("landing", "Can I connect my mIRC to it?"),
     dgettext_noop(
       "landing",
       "No. Retro Hex Chat looks like mIRC and takes its commands, but it is not an IRC server: the mIRC program cannot connect to it, and it cannot connect you to other IRC networks. Everything happens in the browser tab."
     )},
    {dgettext_noop("landing", "Do I need to install anything?"),
     dgettext_noop(
       "landing",
       "No. It runs in any modern browser, on a computer or a phone. Pick a nickname and you are in."
     )},
    {dgettext_noop("landing", "Do I need an account?"),
     dgettext_noop(
       "landing",
       "No. A nickname is enough to chat. To keep it yours, register it with NickServ and a password, the way it worked on IRC."
     )},
    {dgettext_noop("landing", "Is it free?"),
     dgettext_noop(
       "landing",
       "Yes. It costs nothing to use, and the software is open source under the MIT license, so you can also run your own server."
     )}
  ]

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    path = PublicPages.path(:mirc_online)
    questions = Guides.questions(@questions)

    {:ok,
     %{
       active_page: :mirc_online,
       questions: questions,
       links: Guides.links(:mirc_online),
       commands_path: PublicPages.localized_path(PublicPages.path(:mirc_commands)),
       windows: [
         Window.intro(dgettext("landing", "mIRC online, in your browser"), :icon_chat,
           taskbar_label: dgettext("landing", "mIRC online"),
           heading_id: "mirc-online-heading",
           description:
             dgettext(
               "landing",
               "A chat built the way mIRC taught a generation to chat, running in a browser tab: no download, no server list to configure. Pick a nickname, and you are in a channel."
             ),
           status: [dgettext("landing", "Free of charge, nothing to install")]
         ),
         Window.new("the-window", dgettext("landing", "The window you know"), :icon_chat,
           width: 560,
           body: &the_window/1
         ),
         Window.new("carries-over", dgettext("landing", "What stays the same"), :icon_checkmark,
           width: 560,
           body: &carries_over/1
         ),
         Window.new("not-mirc", dgettext("landing", "What it is not"), :icon_shield,
           width: 480,
           body: &not_mirc/1
         ),
         Guides.questions_window(),
         Guides.read_next_window()
       ],
       canonical_path: path,
       json_ld: [Guides.breadcrumb(:mirc_online), SEO.faq_page_json_ld(questions, path)],
       page_title:
         dgettext("landing", "mIRC online: a mIRC-style chat in your browser — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "The mIRC way of chatting — channels, the nick list, slash commands, aliases, popups and perform — in a chat that runs in the browser, free of charge. Nothing to install."
         )
     }}
  end

  embed_templates "mirc_online/*"
end

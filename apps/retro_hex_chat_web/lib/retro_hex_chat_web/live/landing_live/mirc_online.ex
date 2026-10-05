defmodule RetroHexChatWeb.LandingLive.MircOnline do
  @moduledoc """
  The page for someone looking for mIRC online: what of mIRC carries over to
  a chat in the browser, and — said plainly, before they find out — what does
  not. It is not mIRC and not an IRC server, and the page says so.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Landing.IrcGuides

  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.LandingLive.Guides
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

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

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    path = PublicPages.path(:mirc_online)
    questions = Guides.questions(@questions)

    {:ok,
     assign(socket,
       active_page: :mirc_online,
       questions: questions,
       links: Guides.links(:mirc_online),
       commands_path: PublicPages.localized_path(PublicPages.path(:mirc_commands)),
       windows: [
         %{id: "intro", label: dgettext("landing", "mIRC online"), icon: :icon_chat},
         %{id: "the-window", label: dgettext("landing", "The window you know"), icon: :icon_chat},
         %{
           id: "carries-over",
           label: dgettext("landing", "What stays the same"),
           icon: :icon_checkmark
         },
         %{id: "not-mirc", label: dgettext("landing", "What it is not"), icon: :icon_shield},
         %{id: "questions", label: dgettext("landing", "Questions"), icon: :icon_question},
         %{id: "read-next", label: dgettext("landing", "Read next"), icon: :icon_link}
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
     )}
  end
end

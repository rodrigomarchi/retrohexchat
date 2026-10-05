defmodule RetroHexChatWeb.LandingLive.IrcChat do
  @moduledoc """
  The page for someone looking for IRC chat rooms: how a room works here —
  channels, who runs them, how a nickname is kept — and the rooms whose
  conversation can be read before joining.

  The rooms are the channels that publish their archive. Each one links to a
  page a search engine can already read, which is the point of listing them.
  """
  use Phoenix.LiveView
  use Gettext, backend: RetroHexChatWeb.Gettext

  import RetroHexChatWeb.LandingLive.LandingHelpers
  import RetroHexChatWeb.Components.UI.Desktop
  import RetroHexChatWeb.Components.UI.Landing.IrcGuides

  alias RetroHexChat.Chat.Archive
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.LandingLive.Guides
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO

  @questions [
    {dgettext_noop("landing", "Is this an IRC server?"),
     dgettext_noop(
       "landing",
       "No. It works the way IRC does — channels, operators, modes, NickServ and ChanServ — but in the browser, on its own server. IRC clients such as mIRC cannot connect to it."
     )},
    {dgettext_noop("landing", "Can I open my own channel?"),
     dgettext_noop(
       "landing",
       "Yes. Type /join and a name that starts with #. If the channel does not exist yet, it is created and you are its owner. Register it with ChanServ to keep it."
     )},
    {dgettext_noop("landing", "Can I run my own server?"),
     dgettext_noop(
       "landing",
       "Yes. The software is open source under the MIT license, and the install guide shows how to run it on your own machine."
     )}
  ]

  @spec mount(map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:ok, Phoenix.LiveView.Socket.t()}
  def mount(_params, _session, socket) do
    path = PublicPages.path(:irc_chat)
    questions = Guides.questions(@questions)
    rooms = Enum.map(Archive.published_channels(), &%{name: &1, path: Paths.archive_path(&1)})

    {:ok,
     assign(socket,
       active_page: :irc_chat,
       questions: questions,
       rooms: rooms,
       links: Guides.links(:irc_chat),
       windows: windows(rooms),
       canonical_path: path,
       json_ld: [Guides.breadcrumb(:irc_chat), SEO.faq_page_json_ld(questions, path)],
       page_title: dgettext("landing", "IRC chat rooms in your browser — Retro Hex Chat"),
       page_description:
         dgettext(
           "landing",
           "IRC-style chat rooms in the browser: #channels, operators and voice, channel modes, NickServ and ChanServ. Free of charge, with nothing to install."
         )
     )}
  end

  # A server with no published room has no window to show for them, and no
  # taskbar button pointing at one.
  defp windows(rooms) do
    [
      %{id: "intro", label: dgettext("landing", "IRC chat"), icon: :icon_channels},
      %{id: "rooms", label: dgettext("landing", "How a chat room works"), icon: :icon_channels},
      %{id: "who-runs", label: dgettext("landing", "Who runs a chat room"), icon: :icon_shield},
      %{
        id: "keep-your-nickname",
        label: dgettext("landing", "Your nickname"),
        icon: :icon_btn_profile
      }
    ] ++
      if(rooms == [],
        do: [],
        else: [
          %{
            id: "open-rooms",
            label: dgettext("landing", "Read a chat room first"),
            icon: :icon_chat
          }
        ]
      ) ++
      [
        %{id: "questions", label: dgettext("landing", "Questions"), icon: :icon_question},
        %{id: "read-next", label: dgettext("landing", "Read next"), icon: :icon_link}
      ]
  end
end

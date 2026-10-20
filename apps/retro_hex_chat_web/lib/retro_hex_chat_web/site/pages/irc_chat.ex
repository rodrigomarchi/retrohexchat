defmodule RetroHexChatWeb.Site.Pages.IrcChat do
  @moduledoc """
  The page for someone looking for IRC chat rooms: how a room works here —
  channels, who runs them, how a nickname is kept — and the rooms whose
  conversation can be read before joining.

  The rooms are the channels that publish their archive. Each one links to a
  page a search engine can already read, which is the point of listing them.
  """
  use RetroHexChatWeb.Site.Page

  import RetroHexChatWeb.Components.UI.NickFlag, only: [channel_flag: 1]

  alias RetroHexChat.Chat.Archive
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.SEO
  alias RetroHexChatWeb.Site.Pages.Guides

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

  @impl RetroHexChatWeb.Site.Page
  def load(_params, _ctx) do
    path = PublicPages.path(:irc_chat)
    questions = Guides.questions(@questions)

    rooms =
      Enum.map(
        Archive.published_rooms(),
        &%{name: &1.name, locale: &1.locale, path: Paths.archive_path(&1.name)}
      )

    {:ok,
     %{
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
     }}
  end

  # A server with no published room has no window to show for them, and no
  # taskbar button pointing at one.
  defp windows(rooms) do
    [
      Window.new(
        "intro",
        dgettext("landing", "IRC-style chat rooms in your browser"),
        :icon_channels,
        width: 640,
        taskbar_label: dgettext("landing", "IRC chat"),
        body: &page_intro/1,
        assigns: %{
          heading_id: "irc-chat-heading",
          description:
            dgettext(
              "landing",
              "Channels whose names start with #, operators who keep order, and nicknames you can register — the way IRC has always worked, in a browser tab, free and with nothing to install."
            )
        },
        status: [dgettext("landing", "Chat rooms open to anyone")]
      ),
      Window.new("rooms", dgettext("landing", "How a chat room works"), :icon_channels,
        width: 560,
        body: &rooms/1
      ),
      Window.new("who-runs", dgettext("landing", "Who runs a chat room"), :icon_shield,
        width: 520,
        body: &who_runs/1
      ),
      Window.new("keep-your-nickname", dgettext("landing", "Your nickname"), :icon_btn_profile,
        width: 480,
        body: &keep_your_nickname/1
      )
    ] ++
      open_rooms_window(rooms) ++
      [Guides.questions_window(), Guides.read_next_window()]
  end

  defp open_rooms_window([]), do: []

  defp open_rooms_window(_rooms),
    do: [
      Window.new("open-rooms", dgettext("landing", "Read a chat room first"), :icon_chat,
        width: 420,
        body: &open_rooms/1
      )
    ]

  embed_templates "irc_chat/*"
end

defmodule RetroHexChatWeb.Site.Documents do
  @moduledoc """
  The pages of the site as windows of the one desktop, and the address bar as
  the window in front.

  Every address of the desktop is a `live_action`. One that names a page
  (`Site.Registry.page/1`) opens it over the chat — loading it, putting its
  windows on the desktop and its title, description and structured data in the
  head (`Site.Head`). Any other address is the chat's own, and brings the chat
  to the front.

  A page of the site is a group of windows, one per section (`Site.Window`),
  laid out together by the window manager; help, the archive, an invitation
  and sign-in are one window each. Each lives in a slot (`Page.slot/0`): every
  page of the site shares the `:site` slot, the way a browser shows one page
  at a time, while the others keep their own.

  The home is the exception that makes the chat the home: a visitor arriving
  at `/` gets the chat in front, and the home's windows are on the desktop
  closed — their words in the HTML. Coming to the home again from within the
  desktop (its icon, Start ▸ Navigate ▸ Home, a move back) opens them.

  The bridge runs the other way too, from the windows to the address, through
  events the window manager sends, handled here in a hook attached ahead of
  the visitor gate, because moving between windows is something a visitor may
  always do:

    * `window_focused` — a window of a page came to the front: the address
      follows it;
    * `document_closed` — the last window of a page was closed: the address
      goes to whatever is left in front;
    * `open_page` — a desktop icon asked for a page. Its `id` is what every
      desktop icon sends (`data-window-shortcut`), here the page's name in
      `PublicPages`.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView

  alias RetroHexChat.Arcade
  alias RetroHexChat.Channels.Name
  alias RetroHexChat.Channels.Visibility
  alias RetroHexChat.Games.Catalog, as: Games
  alias RetroHexChatWeb.ChatLive.ChatTitle
  alias RetroHexChatWeb.Components.UI.ArcadePlayCard
  alias RetroHexChatWeb.Components.UI.GameResultCard
  alias RetroHexChatWeb.Components.UI.Site.Document
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.Site.Address
  alias RetroHexChatWeb.Site.Head
  alias RetroHexChatWeb.Site.Page.NotFoundError
  alias RetroHexChatWeb.Site.Pages
  alias RetroHexChatWeb.Site.Registry
  alias RetroHexChatWeb.Site.Window

  @bridge_events ~w(window_focused document_closed open_page)

  @type doc :: %{
          slot: RetroHexChatWeb.Site.Page.slot(),
          page: module(),
          title: String.t(),
          icon: atom(),
          windows: [Window.t()],
          open?: boolean(),
          active_page: atom() | nil,
          assigns: map(),
          params: map(),
          address: String.t()
        }

  @doc """
  The desktop's starting point: no page open, and what the session says about
  the reader for pages that care (`trusted_device_id`).
  Attaches the window bridge, which must run before the visitor gate — call
  this before `Visitor.attach_gate/1`.
  """
  @spec init(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def init(socket, http_session) do
    socket
    |> assign(
      docs: %{},
      doc_order: [],
      focused_doc: nil,
      head: Head.from_page(%{}),
      site_session: Map.take(http_session, ["trusted_device_id"])
    )
    |> attach_hook(:site_documents, :handle_event, &event/3)
    |> attach_hook(:site_address, :handle_info, &info/2)
  end

  @doc "Opens what the address names: a page's windows, or the chat."
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_params(params, uri, socket) do
    action = socket.assigns.live_action
    address = address(uri)
    arrival? = is_nil(socket.assigns[:current_address])
    socket = assign(socket, boot: boot(action, socket.assigns), current_address: address)

    cond do
      # A banned nickname keeps the site — anyone can read it — but not the
      # chat's own addresses, which send it to the sign-in window saying why.
      socket.assigns[:banned?] == true and action in [:channel, :join] ->
        redirect(socket, to: Address.localized("/connect?reason=banned"))

      action == :home and not socket.assigns.visitor? ->
        show_chat(socket, "/")

      page = Registry.page(action) ->
        show_page(socket, page, params, address, arrival?)

      true ->
        show_chat(socket, canonical_chat_path(action, params))
    end
  end

  # When the desktop.js starts the chat's LiveSocket (see `lib/site/boot_policy.js`):
  # at once for a member, and for the addresses that are the chat's own or do
  # nothing without it; at once for a reader of the home, whose chat is the
  # home, though not for a crawler; on the reader's first move otherwise.
  defp boot(action, assigns) do
    cond do
      assigns[:visitor?] != true or action in [:channel, :connect, :join] -> "now"
      action == :home -> "reader"
      true -> "deferred"
    end
  end

  @doc "The tab's title while a page is in front, or nil when the chat is and names it."
  @spec tab_title(atom() | nil, %{atom() => doc()}, Head.t()) :: String.t() | nil
  def tab_title(focused, docs, head) when is_map_key(docs, focused), do: head.title
  def tab_title(_focused, _docs, _head), do: nil

  @doc """
  Whether the desktop carries the site's About window: beside a page of the
  site or the archive — the pages that are read and indexed, whose language
  links it holds — and always once the chat is live. The chat's own addresses
  get it with the chat.
  """
  @spec carries_about?(%{atom() => doc()}, boolean()) :: boolean()
  def carries_about?(_docs, true), do: true
  def carries_about?(docs, _live_ready), do: is_map_key(docs, :site) or is_map_key(docs, :archive)

  @doc """
  What the taskbar shows for the pages on screen, in the order they came to the
  desktop: a button for a page of one window, a group of buttons — one per
  window — for a page of the site.
  """
  @spec taskbar(%{atom() => doc()}, [atom()]) :: [
          %{
            slot: atom(),
            label: String.t(),
            icon: atom(),
            windows: [%{id: String.t(), label: String.t(), window: Window.t()}]
          }
        ]
  def taskbar(docs, order) do
    for slot <- Enum.reverse(order), doc = docs[slot], doc.open? do
      windows =
        Enum.map(
          doc.windows,
          &%{id: Document.dom_id(doc, &1), label: Window.label(&1), window: &1}
        )

      %{slot: slot, label: doc.title, icon: doc.icon, windows: windows}
    end
  end

  # ── Pages ─────────────────────────────────────────────────────

  # A page already on the desktop at this very address is not loaded again:
  # the reader clicked one of its windows, or went back to it, and its windows
  # keep where they were. The home closed behind a visitor's chat, asked for
  # again, opens where it is.
  defp show_page(socket, page, params, address, arrival?) do
    case socket.assigns.docs[page.slot()] do
      %{page: ^page, address: ^address, open?: true} = doc -> refocus(socket, doc)
      %{page: ^page, address: ^address} = doc when not arrival? -> reopen(socket, doc)
      _doc -> open_page(socket, page, params, address, opens?(page, arrival?))
    end
  end

  defp open_page(socket, page, params, address, open?) do
    case page.load(params, ctx(socket)) do
      {:ok, loaded} ->
        doc = page |> build(loaded, address, open?) |> Map.put(:params, params)
        head = Head.from_page(loaded)

        socket
        |> assign(
          docs: Map.put(socket.assigns.docs, doc.slot, doc),
          doc_order: [doc.slot | List.delete(socket.assigns.doc_order, doc.slot)],
          head: head,
          initial_title: head.title
        )
        |> present(doc)
        |> sync_head(head)

      {:redirect, to} ->
        redirect(socket, to: to)

      # Reached by a patch — a pager to a day since withdrawn — the address is
      # loaded whole, so the reader gets the same 404 a robot does.
      :not_found ->
        if connected?(socket), do: redirect(socket, to: address), else: raise(NotFoundError)
    end
  end

  # Every page opens when the reader comes to it. The home is the exception on
  # a visitor's arrival: the chat is what the home shows, so its windows wait
  # closed behind it — one desktop icon, the Start menu's Home or a move back
  # to the home away, each of which comes to it again.
  defp opens?(Pages.Index, arrival?), do: not arrival?
  defp opens?(_page, _arrival?), do: true

  defp present(socket, %{open?: true} = doc) do
    socket |> assign(focused_doc: doc.slot) |> command(open_action(doc), window_target(doc))
  end

  defp present(socket, %{open?: false}) do
    socket |> assign(focused_doc: nil) |> command("focus", "chat")
  end

  # A page already on the desktop comes to the front: the window manager
  # raises its windows (a no-op when the reader's own click already did), and
  # the head speaks for it again.
  defp refocus(socket, doc) do
    socket
    |> take_front(doc)
    |> command(open_action(doc), window_target(doc))
  end

  # The page is in front: the head speaks for it again.
  defp take_front(socket, doc) do
    head = Head.from_page(doc.assigns)

    socket
    |> assign(focused_doc: doc.slot, head: head)
    |> sync_head(head)
  end

  # A page of the site goes by its name in the menus' list (`PublicPages`); a
  # page of one window, by that window.
  defp build(page, loaded, address, open?) do
    slot = page.slot()
    windows = Map.fetch!(loaded, :windows)
    named = (slot == :site && PublicPages.find(loaded[:active_page])) || hd(windows)

    %{
      slot: slot,
      page: page,
      title: named.title,
      icon: named.icon,
      windows: windows,
      open?: open?,
      active_page: loaded[:active_page],
      assigns: loaded,
      params: %{},
      address: address
    }
  end

  @doc """
  Loads `page` again when it is the page open in its slot — its windows and
  what they say, in place, without moving the reader's focus. A page whose
  words change while it is read (a game's home: who is playing, who won)
  stays current this way.
  """
  @spec refresh(Phoenix.LiveView.Socket.t(), module()) :: Phoenix.LiveView.Socket.t()
  def refresh(socket, page) do
    with %{page: ^page, open?: true, params: params} = doc <- socket.assigns.docs[page.slot()],
         {:ok, loaded} <- page.load(params, ctx(socket)) do
      doc = %{doc | windows: Map.fetch!(loaded, :windows), assigns: loaded}
      assign(socket, docs: Map.put(socket.assigns.docs, doc.slot, doc))
    else
      _closed_or_gone -> socket
    end
  end

  defp ctx(socket) do
    assigns = socket.assigns

    %{
      locale: assigns[:locale],
      visitor?: assigns[:visitor?] == true,
      nickname: if(assigns[:visitor?], do: nil, else: assigns.session.nickname),
      # Proved in this chat session — not merely a registered nickname typed in.
      identified?: assigns[:visitor?] != true and assigns.session.identified == true,
      connected?: connected?(socket),
      session: assigns.site_session,
      chat_address: Address.chat_address(assigns)
    }
  end

  # ── The chat ──────────────────────────────────────────────────

  defp show_chat(socket, canonical_path) do
    head = Head.for_chat(chat_title(socket.assigns, canonical_path), canonical_path)

    socket
    |> assign(focused_doc: nil, head: head)
    |> command("focus", "chat")
    |> sync_head(head)
  end

  defp canonical_chat_path(:channel, %{"channel" => channel}), do: Address.channel_path(channel)
  defp canonical_chat_path(_action, _params), do: "/"

  # A channel names itself only when a stranger could have listed it anyway:
  # the title of an address is what a shared link unfurls into.
  defp chat_title(_assigns, "/c/" <> _ = path) do
    channel = path |> String.replace_prefix("/c/", "") |> URI.decode() |> Name.ensure_prefix()

    cond do
      not Visibility.nameable?(channel) -> "RetroHexChat"
      game = game_named(channel) -> "#{channel} — #{game} — RetroHexChat"
      true -> "#{channel} — RetroHexChat"
    end
  end

  defp chat_title(assigns, _path), do: ChatTitle.document_title(assigns.session, false)

  # A game's channel says which game it is about in a shared link's preview.
  defp game_named(channel) do
    case {Games.game_for_channel(channel), Arcade.game_for_channel(channel)} do
      {{:ok, game_id}, _arcade} -> GameResultCard.game_title(game_id)
      {:error, {:ok, game_id}} -> ArcadePlayCard.game_title(game_id)
      {:error, :error} -> nil
    end
  end

  # ── From the windows to the address ───────────────────────────

  defp event("window_focused", %{"id" => "chat"}, socket) do
    {:halt, to_chat(socket, replace: true)}
  end

  # A slot that names no page on screen — never one, or one already gone —
  # asks for nothing, and is not the visitor gate's to answer either.
  defp event("window_focused", %{"slot" => name}, socket) do
    case open_doc(socket, Registry.slot(name)) do
      nil -> {:halt, socket}
      doc -> {:halt, follow_doc(socket, doc)}
    end
  end

  defp event("document_closed", %{"slot" => name}, socket) do
    case open_doc(socket, Registry.slot(name)) do
      nil -> {:halt, socket}
      doc -> {:halt, close(socket, doc)}
    end
  end

  # The icon names its page; a name that is no page of the site asks for
  # nothing, and is not the visitor gate's to answer either.
  defp event("open_page", %{"id" => key}, socket) do
    case Enum.find(PublicPages.all(), &(Atom.to_string(&1.page) == key)) do
      nil -> {:halt, socket}
      entry -> {:halt, request_page(socket, entry)}
    end
  end

  # The bridge's own events, malformed: still the bridge's, still nothing to do.
  defp event(event, _params, socket) when event in @bridge_events, do: {:halt, socket}

  defp event(_event, _params, socket), do: {:cont, socket}

  defp info({Address, :sync_address}, socket), do: {:halt, Address.follow(socket)}

  # A match of the game whose home is open was just written down: its ranking,
  # its latest matches and the reader's own record have moved.
  defp info({:game_result_recorded, %{base_id: base_id}}, socket) do
    case socket.assigns.docs[:site] do
      %{page: Pages.Game, assigns: %{game: %{id: ^base_id}}} ->
        {:halt, refresh(socket, Pages.Game)}

      _other_page ->
        {:halt, socket}
    end
  end

  # Somebody started the arcade game whose page is open: its latest players
  # and its week have moved.
  defp info({:arcade_play_started, %{game_id: game_id}}, socket) do
    case socket.assigns.docs[:site] do
      %{page: Pages.Game, assigns: %{game: %{kind: :arcade, id: ^game_id}}} ->
        {:halt, refresh(socket, Pages.Game)}

      _other_page ->
        {:halt, socket}
    end
  end

  defp info(_message, socket), do: {:cont, socket}

  defp open_doc(_socket, nil), do: nil

  defp open_doc(socket, slot) do
    case socket.assigns.docs[slot] do
      %{open?: true} = doc -> doc
      _closed_or_absent -> nil
    end
  end

  # The reader brought one of a page's windows to the front: the page is in
  # front now, and the address says so — replaced, since moving between
  # windows is not a place to go back to.
  defp follow_doc(socket, doc) do
    if doc.address == socket.assigns[:current_address] do
      take_front(socket, doc)
    else
      push_patch(socket, to: doc.address, replace: true)
    end
  end

  # A page the reader asked for from a desktop icon: its address opens it — in
  # place when it is the address already in the bar, the home closed behind a
  # visitor's chat.
  defp request_page(socket, %{path: path}) do
    address = Address.localized(path)
    push_patch(socket, to: address, replace: address == socket.assigns[:current_address])
  end

  defp reopen(socket, doc) do
    doc = %{doc | open?: true}

    socket
    |> assign(
      docs: Map.put(socket.assigns.docs, doc.slot, doc),
      doc_order: [doc.slot | List.delete(socket.assigns.doc_order, doc.slot)]
    )
    |> refocus(doc)
  end

  # The home's windows belong to the home's HTML whatever the reader does with
  # them, so closing them only puts them away; any other page closed leaves
  # the desktop.
  defp close(socket, %{page: Pages.Index} = doc) do
    socket
    |> assign(docs: Map.put(socket.assigns.docs, doc.slot, %{doc | open?: false}))
    |> after_close(doc.slot)
  end

  defp close(socket, doc) do
    socket
    |> assign(
      docs: Map.delete(socket.assigns.docs, doc.slot),
      doc_order: List.delete(socket.assigns.doc_order, doc.slot)
    )
    |> after_close(doc.slot)
  end

  defp after_close(socket, closed) do
    front =
      Enum.find(socket.assigns.doc_order, &(&1 != closed and open_doc(socket, &1) != nil))

    case front do
      nil -> to_chat(socket, replace: false)
      slot -> push_patch(socket, to: socket.assigns.docs[slot].address)
    end
  end

  # The chat comes to the front at its own address — or in place, when that
  # address is the one already in the bar, or when the bar is at the home and
  # the chat is showing the conversation the home opens with.
  defp to_chat(socket, replace: replace) do
    address = Address.chat_address(socket.assigns)

    if address == socket.assigns[:current_address] or Address.home_conversation?(socket.assigns) do
      show_chat(socket, Address.chat_path(socket.assigns))
    else
      push_patch(socket, to: address, replace: replace)
    end
  end

  # ── Client side ───────────────────────────────────────────────

  defp open_action(%{slot: :site}), do: "open_group"
  defp open_action(_doc), do: "open"

  defp window_target(%{slot: :site}), do: Document.group()
  defp window_target(doc), do: Registry.window_id(doc.slot)

  defp command(socket, action, id) do
    if connected?(socket),
      do: push_event(socket, "window_command", %{action: action, id: id}),
      else: socket
  end

  defp sync_head(socket, head) do
    if connected?(socket) do
      push_event(socket, "head:sync", %{
        description: head.description,
        canonical: head.canonical_url,
        robots: head.robots
      })
    else
      socket
    end
  end

  defp address(uri) do
    %URI{path: path, query: query} = URI.parse(uri)
    if query in [nil, ""], do: path, else: path <> "?" <> query
  end
end

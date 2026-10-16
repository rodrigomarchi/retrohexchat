defmodule RetroHexChatWeb.Site.Documents do
  @moduledoc """
  The pages of the site as windows of the one desktop, and the address bar as
  the window in front.

  Every address of the desktop is a `live_action`. One that names a page
  (`Site.Registry.page/1`) opens that page's document window over the chat —
  loading it, putting its words in the window and its title, description and
  structured data in the head (`Site.Head`). Any other address is the chat's
  own, and brings the chat to the front.

  The bridge runs the other way too, from the windows to the address. Closing
  a document window patches to whatever is left in front; focusing a window
  replaces the address with that window's. Both arrive as events the window
  manager sends, handled here in a hook attached ahead of the visitor gate,
  because moving between windows is something a visitor may always do.

  Pages share one window per slot (`Page.slot/0`): every page of the site opens
  in the same one, the way a browser shows one page at a time, while help, the
  archive, an invitation and sign-in each keep their own.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView

  alias RetroHexChat.Channels.Visibility
  alias RetroHexChatWeb.ChatLive.ChatTitle
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.Site.Address
  alias RetroHexChatWeb.Site.Head
  alias RetroHexChatWeb.Site.Page.NotFoundError
  alias RetroHexChatWeb.Site.Registry

  @type doc :: %{
          slot: atom(),
          page: module(),
          id: String.t(),
          title: String.t(),
          icon: atom(),
          meta: String.t() | nil,
          menu: :site | :help | :connect | nil,
          sections: [map()],
          active_page: atom() | nil,
          assigns: map(),
          address: String.t()
        }

  @doc """
  The desktop's starting point: no document open, and what the session says
  about the reader for pages that care (`trusted_device_id`, the last
  disconnect). Attaches the window bridge, which must run before the visitor
  gate — call this before `Visitor.attach_gate/1`.
  """
  @spec init(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def init(socket, http_session) do
    socket
    |> assign(
      docs: %{},
      doc_order: [],
      focused_doc: nil,
      head: Head.from_page(%{}),
      site_session: Map.take(http_session, ["trusted_device_id", "last_disconnect_context"])
    )
    |> attach_hook(:site_documents, :handle_event, &event/3)
    |> attach_hook(:site_address, :handle_info, &info/2)
  end

  @doc "Opens what the address names: a page's document window, or the chat."
  @spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) ::
          Phoenix.LiveView.Socket.t()
  def handle_params(params, uri, socket) do
    action = socket.assigns.live_action
    socket = assign(socket, boot: boot(action, socket.assigns), current_address: address(uri))

    cond do
      # A banned nickname keeps the site — anyone can read it — but not the
      # chat's own addresses, which send it to the sign-in window saying why.
      socket.assigns[:banned?] == true and action in [:channel, :join] ->
        redirect(socket, to: Address.localized("/connect?reason=banned"))

      action == :home and not socket.assigns.visitor? ->
        show_chat(socket, "/")

      page = Registry.page(action) ->
        open_page(socket, page, params, address(uri))

      true ->
        show_chat(socket, canonical_chat_path(action, params))
    end
  end

  # When the desktop.js starts the chat's LiveSocket (see `lib/site/boot_policy.js`):
  # at once for a member, and for the addresses that are the chat's own or do
  # nothing without it; on the reader's first move otherwise.
  defp boot(action, assigns) do
    if assigns[:visitor?] != true or action in [:channel, :connect, :join],
      do: "now",
      else: "deferred"
  end

  @doc "The tab's title: the document in front, or the chat's."
  @spec tab_title(map()) :: String.t()
  def tab_title(%{focused_doc: slot, docs: docs} = assigns) when is_atom(slot) and slot != nil do
    case docs do
      %{^slot => _doc} -> assigns.head.title
      _ -> ChatTitle.document_title(assigns.session, assigns.show_status_tab)
    end
  end

  def tab_title(assigns), do: ChatTitle.document_title(assigns.session, assigns.show_status_tab)

  @doc "The document windows, frontmost last, for the template."
  @spec ordered(map()) :: [doc()]
  def ordered(%{docs: docs, doc_order: order}) do
    order |> Enum.reverse() |> Enum.flat_map(&List.wrap(Map.get(docs, &1)))
  end

  # ── Pages ─────────────────────────────────────────────────────

  defp open_page(socket, page, params, address) do
    case page.load(params, ctx(socket)) do
      {:ok, loaded} ->
        doc = build(page, loaded, address)
        head = Head.from_page(loaded)

        socket
        |> assign(
          docs: Map.put(socket.assigns.docs, doc.slot, doc),
          doc_order: [doc.slot | List.delete(socket.assigns.doc_order, doc.slot)],
          focused_doc: doc.slot,
          head: head,
          initial_title: head.title
        )
        |> command("open", doc.id)
        |> sync_head(head)

      {:redirect, to} ->
        redirect(socket, to: to)

      # Reached by a patch — a pager to a day since withdrawn — the address is
      # loaded whole, so the reader gets the same 404 a robot does.
      :not_found ->
        if connected?(socket), do: redirect(socket, to: address), else: raise(NotFoundError)
    end
  end

  defp build(page, loaded, address) do
    slot = page.slot()
    nav = nav_entry(loaded[:active_page])

    %{
      slot: slot,
      page: page,
      id: Registry.window_id(slot),
      title: loaded[:window_title] || (nav && nav.label) || "Retro Hex Chat",
      icon: loaded[:window_icon] || (nav && nav.icon) || :icon_hex_stone,
      meta: loaded[:window_meta],
      menu: Map.get(loaded, :menu, :site),
      sections: loaded[:windows] || [],
      active_page: loaded[:active_page],
      assigns: loaded,
      address: address
    }
  end

  defp nav_entry(nil), do: nil

  defp nav_entry(page) do
    Enum.find(PublicPages.all() ++ PublicPages.guides(), &(&1.page == page))
  end

  defp ctx(socket) do
    assigns = socket.assigns

    %{
      locale: assigns[:locale],
      visitor?: assigns[:visitor?] == true,
      nickname: if(assigns[:visitor?], do: nil, else: assigns.session.nickname),
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
    channel = path |> String.replace_prefix("/c/", "") |> URI.decode() |> Address.channel_name()

    if Visibility.nameable?(channel),
      do: "#{channel} — RetroHexChat",
      else: "RetroHexChat"
  end

  defp chat_title(assigns, _path), do: ChatTitle.document_title(assigns.session, false)

  # ── From the windows to the address ───────────────────────────

  defp event("window_closed", %{"id" => id}, socket) do
    case Registry.slot_of(id) do
      nil -> {:cont, socket}
      slot -> {:halt, close(socket, slot)}
    end
  end

  defp event("window_focused", %{"id" => "chat"}, socket) do
    {:halt, to_chat(socket, replace: true)}
  end

  defp event("window_focused", %{"id" => id}, socket) do
    with slot when slot != nil <- Registry.slot_of(id),
         %{address: address} <- socket.assigns.docs[slot] do
      {:halt, push_patch(socket, to: address, replace: true)}
    else
      _ -> {:cont, socket}
    end
  end

  # A document window lives as long as its address does; the window manager
  # asking to mount one it lost track of has nothing to mount.
  defp event("window_open", %{"id" => id}, socket) do
    if Registry.slot_of(id), do: {:halt, socket}, else: {:cont, socket}
  end

  defp event(_event, _params, socket), do: {:cont, socket}

  defp info({Address, :sync_address}, socket), do: {:halt, Address.follow(socket)}
  defp info(_message, socket), do: {:cont, socket}

  defp close(socket, slot) do
    order = List.delete(socket.assigns.doc_order, slot)
    socket = assign(socket, docs: Map.delete(socket.assigns.docs, slot), doc_order: order)

    case order do
      [front | _rest] -> push_patch(socket, to: socket.assigns.docs[front].address)
      [] -> to_chat(socket, replace: false)
    end
  end

  # The chat comes to the front at its own address. When that address is the
  # one already in the bar — the home, for a visitor whose chat has no channel
  # in front — patching to it would only reopen the home's Welcome over the
  # chat the reader just asked for, so the chat is brought forward in place.
  defp to_chat(socket, replace: replace) do
    address = Address.chat_address(socket.assigns)

    if address == socket.assigns[:current_address] do
      show_chat(socket, Address.chat_path(socket.assigns))
    else
      push_patch(socket, to: address, replace: replace)
    end
  end

  # ── Client side ───────────────────────────────────────────────

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

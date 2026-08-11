defmodule RetroHexChatWeb.ChatLive.Components.MessageViewport do
  @moduledoc """
  The main chat message viewport. Owns the `:chat_messages` stream and renders one
  `MessageRow` per message, so the message list re-renders only when a message is
  added, changed or removed — not on every parent re-render (typing, lag, sidebar
  churn). The per-row markup lives in the pure `MessageRow` function component.

  The parent stays the canonical owner of all pagination/scroll state
  (`oldest_message_id`, `has_more`, `loaded_message_count`,
  `chat_clear_token`, `cleared_conversation_cutoffs`) and of the message-production
  logic (commands, PubSub
  inserts, edits/deletes, load-more pagination, pending reconciliation, cleared-
  channel checks). Wherever that logic would mutate the stream it instead pushes a
  delta here via `send_update/2`:

    * `insert/2` — append or update a single message row
    * `delete/2` — remove a row by message id
    * `reset/2`  — replace the whole list (channel/PM switch, load-more, clear)
    * `attach_preview/3` — decorate the rows waiting on a page that just landed

  Rows are decorated here, on their way into the stream: a link in a message
  carries the same Markdown card the RSS bot publishes, read from the scraper's
  archive and never from the network.

  Context (`chat_clear_token`, `nick_color_fn`, `timestamp_format`, `timezone`,
  `strip_formatting`, `edit_mode_message_id`, `show_status_tab`) is supplied by the
  parent each render. `ChatViewportHook` (auto-scroll, tooltips, context menu) and
  `ChatPaginationHook` (asks for older pages) push to the parent LiveView, which
  holds the scroll/pagination state they drive. Neither sits on the scrolling
  element — see the note in `render/1` for why that matters.

  The channel-load spinner (`loading_channel`) renders here too, co-located with
  the messages it describes. The flag stays parent-owned (the channel switch
  sets and clears it) and is passed through each render — only its visuals live
  in this component.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.ActivityIndicator
  import RetroHexChatWeb.Components.UI.ListStates

  alias RetroHexChat.Scraper
  alias RetroHexChatWeb.ChatLive.Components.MessageRow
  alias RetroHexChatWeb.ChatLive.Helpers.Session, as: SessionHelpers

  @id "message-viewport"

  # The live tail is capped: a session that sits in a busy channel for a day
  # cannot grow the document without bound.
  #
  # The cap applies to arriving messages only, never to scrollback. LiveView
  # prunes a negative limit from the *front* of the list, which is exactly where
  # a prepended page lands — a capped prepend is removed by the same patch that
  # inserted it, while the server's cursor has already moved past those rows, so
  # the reader can never ask for them again. Capping both ends of a list only
  # one of which can be refetched is what turns a page into a page spent.
  #
  # Once the reader has paged back, `scrollback?` lifts the cap for the rest of
  # their stay in the channel: an arriving message must not push the oldest row
  # they just loaded out of the document either. Switching channel or PM resets
  # the stream and the flag together.
  @page_size 50
  @dom_limit @page_size * 3

  @doc "Stable component id used by the parent for `send_update/2`."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Appends or updates a single message row. Returns the socket."
  @spec insert(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def insert(socket, msg) do
    send_update(__MODULE__, id: @id, action: {:insert, msg})
    socket
  end

  @doc "Prepends a chronological page of older messages. Returns the socket."
  @spec prepend(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  def prepend(socket, items) do
    send_update(__MODULE__, id: @id, action: {:prepend, items})
    socket
  end

  @doc "Removes a single message row by id. Returns the socket."
  @spec delete(Phoenix.LiveView.Socket.t(), term()) :: Phoenix.LiveView.Socket.t()
  def delete(socket, id) do
    send_update(__MODULE__, id: @id, action: {:delete, id})
    socket
  end

  @doc "Replaces the whole message list (channel/PM switch, load-more, clear). Returns the socket."
  @spec reset(Phoenix.LiveView.Socket.t(), [map()]) :: Phoenix.LiveView.Socket.t()
  def reset(socket, items) do
    send_update(__MODULE__, id: @id, action: {:reset, items})
    socket
  end

  @doc """
  Re-renders the rows already on screen, without reading the database.

  A stream does not restyle existing rows on an ordinary re-render, so a change
  to per-row presentation — a nick colour, a timestamp format — has to re-stream
  them. It used to do that by re-running the history query for however many
  messages were loaded, which meant a colour change after a long scrollback
  re-read thousands of rows to paint them differently.
  """
  @spec restyle(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def restyle(socket) do
    send_update(__MODULE__, id: @id, action: :restyle)
    socket
  end

  @doc """
  Gives the rows waiting on a page the card it just became. Returns the socket.

  A link pasted a second before the scrape finished would otherwise stay bare
  until the reader reloaded, because a stream does not re-render a row nobody
  re-inserts. Only rows already tagged with this fingerprint are touched, so a
  page nobody in this session linked costs a list scan and nothing else.
  """
  @spec attach_preview(Phoenix.LiveView.Socket.t(), String.t(), String.t()) ::
          Phoenix.LiveView.Socket.t()
  def attach_preview(socket, url, url_hash) do
    send_update(__MODULE__, id: @id, action: {:attach_preview, url, url_hash})
    socket
  end

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok,
     socket
     |> assign(
       id: @id,
       chat_clear_token: 0,
       nick_color_fn: fn _nick -> nil end,
       timestamp_format: :dd_mm_hh_mm,
       timezone: "Etc/UTC",
       strip_formatting: false,
       edit_mode_message_id: nil,
       show_status_tab: false,
       loading_channel: nil,
       has_more: false,
       viewer: nil,
       rendered: [],
       scrollback?: false
     )
     |> stream(:chat_messages, [], limit: -@dom_limit)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:insert, msg}}, socket) do
    msg = decorate(msg)

    {:ok,
     socket
     |> track(fn rendered -> upsert(rendered, msg) end)
     |> stream_insert(:chat_messages, msg, tail_opts(socket))}
  end

  # Items arrive oldest-first; inserting reversed at position 0 lands them in
  # order above the existing rows (a load-more must never reset the stream —
  # ephemeral system lines are not in the DB and would vanish). No limit: see
  # the note on `@dom_limit` — a limit here deletes the page being inserted.
  def update(%{action: {:prepend, items}}, socket) do
    items = decorate_all(items)

    {:ok,
     items
     |> Enum.reverse()
     |> Enum.reduce(
       socket
       |> assign(:scrollback?, true)
       |> track(fn rendered -> items ++ rendered end),
       &stream_insert(&2, :chat_messages, &1, at: 0)
     )}
  end

  def update(%{action: {:delete, id}}, socket) do
    {:ok,
     socket
     |> track(fn rendered -> Enum.reject(rendered, &(&1.id == id)) end)
     |> stream_delete(:chat_messages, %{id: id})}
  end

  # A reset is a new context — the scrollback the reader had loaded belongs to
  # the channel they left, so the cap comes back with it.
  #
  # The client is told, rather than left to infer it from the shape of the DOM
  # patch. A rebuilt list and a prepended page reach a MutationObserver as the
  # same thing (rows removed, rows added), and guessing between them is what
  # used to throw a reader paging through history down to the newest message.
  def update(%{action: {:reset, items}}, socket) do
    items = decorate_all(items)

    {:ok,
     socket
     |> assign(:scrollback?, false)
     |> track(fn _rendered -> items end)
     |> stream(:chat_messages, items, reset: true, limit: -@dom_limit)
     |> push_event("chat_scroll_reset", %{})}
  end

  # Only the rows that were waiting on this page, re-streamed one at a time. A
  # reset would throw a reader who is somewhere in the middle of a conversation
  # down to the newest line, and a capped insert would drop the oldest row on
  # screen — both to say something about one message that is already there.
  def update(%{action: {:attach_preview, url, url_hash}}, socket) do
    case Enum.filter(socket.assigns.rendered, &(Map.get(&1, :link_preview_hash) == url_hash)) do
      [] -> {:ok, socket}
      waiting -> {:ok, attach_card(socket, url, waiting)}
    end
  end

  # Re-streaming what is already held is what makes a presentation change cost
  # nothing at the database. The limit is the number of rows being re-streamed,
  # so restyling a loaded scrollback cannot silently shorten it.
  def update(%{action: :restyle}, socket) do
    rendered = socket.assigns.rendered

    {:ok,
     socket
     |> stream(:chat_messages, rendered,
       reset: true,
       limit: -max(@dom_limit, length(rendered))
     )
     |> push_event("chat_scroll_reset", %{})}
  end

  def update(assigns, socket) do
    keys = [
      :chat_clear_token,
      :nick_color_fn,
      :timestamp_format,
      :timezone,
      :strip_formatting,
      :edit_mode_message_id,
      :show_status_tab,
      :loading_channel,
      :has_more,
      :viewer
    ]

    merged =
      Enum.reduce(keys, %{}, fn key, acc ->
        Map.put(acc, key, Map.get(assigns, key, socket.assigns[key]))
      end)

    {:ok, assign(socket, Map.put(merged, :id, Map.get(assigns, :id, socket.assigns.id)))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.activity_indicator
        :if={@loading_channel != nil}
        icon={:chat}
        variant="panel"
        class="message-viewport__channel-loader"
        text={
          dgettext("chat", "Loading %{channel}...",
            channel: @loading_channel || dgettext("chat", "messages")
          )
        }
        data-testid="channel-loader"
      />

      <%!-- Placeholder rows under the spinner: a spinner alone leaves the
            viewport empty, so the first page lands into a blank box and shoves
            the layout down. The skeleton reserves the space it will occupy. --%>
      <.list_skeleton
        :if={@loading_channel != nil}
        rows={5}
        class="message-viewport__skeleton"
      />

      <%!-- Three elements, three jobs, deliberately not the same element.

            Any event pushed to the server — from a hook or from a `JS.push`
            binding — stamps `data-phx-ref-lock` on the element it was pushed
            from, and every patch arriving while that ref is in flight is
            applied to a *detached clone* of it, then swapped back on the ack.
            A scroll container treated that way loses its scroll position, and
            the swap-back reaches the DOM as a wholesale add-and-remove. When
            the scroller was also the hook element, asking for older messages
            destroyed the reader's place in the very list it was fetching for.

            So: the scroller pushes nothing, the pagination sentinel is the only
            thing inside it that talks to the server, and everything that pushes
            on the reader's behalf (tooltips, hover cards, context menu) lives on
            `chat-viewport-driver`, outside the scroller entirely. --%>
      <div id="chat-viewport-driver" phx-hook="ChatViewportHook" hidden></div>

      <.chat_message_list
        id="chat-messages"
        fill
        hidden={@show_status_tab}
        data-chat-scroller
        data-clear-token={@chat_clear_token}
      >
        <%!-- Fires a screenful before the top so paging back reads as
              continuous. It is the only element in here that pushes. --%>
        <div
          id="chat-load-older"
          phx-hook="ChatPaginationHook"
          data-has-more={to_string(@has_more)}
          aria-hidden="true"
        >
        </div>

        <div id="chat-message-stream" phx-update="stream">
          <MessageRow.message_row
            :for={{dom_id, msg} <- @streams.chat_messages}
            dom_id={dom_id}
            msg={msg}
            nick_color_fn={@nick_color_fn}
            timestamp_format={@timestamp_format}
            timezone={@timezone}
            strip_formatting={@strip_formatting}
            edit_mode_message_id={@edit_mode_message_id}
            viewer={@viewer}
          />
        </div>

        <%!-- The browser's own scroll anchoring keeps the newest line in view:
              this is the only anchor candidate in the list, so while it is on
              screen the viewport follows content appended above it, and once
              the reader scrolls away from it nothing tugs at them. --%>
        <div id="chat-bottom-anchor" aria-hidden="true"></div>
      </.chat_message_list>
    </div>
    """
  end

  # The rows currently on screen, kept alongside the stream because a stream
  # cannot be read back. Trimmed by the same rule as the DOM, from the same end,
  # so the two never disagree about what is rendered — including once a
  # scrollback has lifted the cap, where trimming here would make `restyle/1`
  # re-stream a shorter list than the one on screen.
  @spec track(Phoenix.LiveView.Socket.t(), ([map()] -> [map()])) :: Phoenix.LiveView.Socket.t()
  defp track(socket, fun) do
    rendered = fun.(socket.assigns.rendered)
    rendered = if socket.assigns.scrollback?, do: rendered, else: Enum.take(rendered, -@dom_limit)
    assign(socket, rendered: rendered)
  end

  # An arriving message drops the oldest row once the tail is full, and drops
  # nothing at all once the reader has paged back.
  @spec tail_opts(Phoenix.LiveView.Socket.t()) :: keyword()
  defp tail_opts(%{assigns: %{scrollback?: true}}), do: []
  defp tail_opts(_socket), do: [limit: -@dom_limit]

  @spec upsert([map()], map()) :: [map()]
  defp upsert(rendered, msg) do
    case Enum.find_index(rendered, &(&1.id == msg.id)) do
      nil -> rendered ++ [msg]
      index -> List.replace_at(rendered, index, msg)
    end
  end

  # ── Link cards ─────────────────────────────────────────────
  #
  # A link somebody pasted gets the same Markdown card an RSS bot publishes, from
  # the same archive and the same `Scraper.Card`. Decorating here rather than in
  # the three places that build stream items means it applies to arriving
  # messages, to a channel switch and to a page of scrollback alike — and it
  # survives a reload, which the client-side title span it replaces never did.
  #
  # Never a request: this runs on a render path, so a page nobody has scraped yet
  # simply has no card until the scrape lands and `attach_preview/3` says so.

  # Only messages that are plain conversation. A Markdown message is authored
  # presentation — whoever wrote it already decided how the link should look, and
  # for the RSS bot the message *is* a card, so adding one underneath would print
  # the same page twice. The rule reads off the message rather than off its
  # author on purpose: a bot whose process is not running still published a card,
  # and a nickname is not evidence of anything once history is being replayed.
  @card_types [:message, :action]
  @card_formats ["irc", "plain"]

  @spec decorate(map()) :: map()
  defp decorate(msg), do: msg |> List.wrap() |> decorate_all() |> hd()

  @spec decorate_all([map()]) :: [map()]
  defp decorate_all([]), do: []

  defp decorate_all(items) do
    items = Enum.map(items, &tag_link/1)

    cards =
      items
      |> Enum.map(&Map.get(&1, :link_preview_hash))
      |> Enum.reject(&is_nil/1)
      |> Scraper.cards()

    Enum.map(items, &put_card(&1, cards))
  end

  # The fingerprint is recorded even when the archive has nothing yet: it is what
  # lets a page that lands later find the rows waiting for it.
  @spec tag_link(map()) :: map()
  defp tag_link(msg) do
    with true <- previewable?(msg),
         [url | _rest] <- SessionHelpers.extract_content_urls(msg.content, card_format(msg)),
         url_hash when is_binary(url_hash) <- Scraper.fingerprint(url) do
      Map.put(msg, :link_preview_hash, url_hash)
    else
      _ -> msg
    end
  end

  @spec put_card(map(), %{String.t() => String.t()}) :: map()
  defp put_card(%{link_preview_hash: url_hash} = msg, cards) do
    case Map.fetch(cards, url_hash) do
      {:ok, markdown} -> Map.put(msg, :link_preview, markdown)
      :error -> msg
    end
  end

  defp put_card(msg, _cards), do: msg

  @spec previewable?(map()) :: boolean()
  defp previewable?(msg) do
    Map.get(msg, :type, :message) in @card_types and
      card_format(msg) in @card_formats and
      is_binary(Map.get(msg, :content)) and
      is_nil(Map.get(msg, :deleted_at))
  end

  @spec card_format(map()) :: String.t()
  defp card_format(msg), do: Map.get(msg, :content_format) || "irc"

  @spec attach_card(Phoenix.LiveView.Socket.t(), String.t(), [map()]) ::
          Phoenix.LiveView.Socket.t()
  defp attach_card(socket, url, waiting) do
    with {:ok, page} <- Scraper.get(url),
         markdown when is_binary(markdown) <- Scraper.card(page) do
      decorated = Enum.map(waiting, &Map.put(&1, :link_preview, markdown))

      socket
      |> track(fn rendered -> Enum.reduce(decorated, rendered, &upsert(&2, &1)) end)
      |> then(
        &Enum.reduce(decorated, &1, fn msg, acc -> stream_insert(acc, :chat_messages, msg) end)
      )
    else
      _ -> socket
    end
  end
end

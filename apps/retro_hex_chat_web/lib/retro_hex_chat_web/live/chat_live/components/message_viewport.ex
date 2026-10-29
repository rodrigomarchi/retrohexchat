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
    * `insert_if_present/2` — refresh a row only if it is already on screen
    * `delete/2` — remove a row by message id
    * `reset/2`  — replace the whole list (channel/PM switch, load-more, clear)
    * `attach_preview/3` — decorate the rows waiting on a page that just landed

  Rows are decorated here, on their way into the stream: a link in a message
  carries the same Markdown card the RSS bot publishes, read from the scraper's
  archive and never from the network. Each row is also placed in its speaker's
  run (`MessageGrouping`), against the rows `rendered` says are around it, so a
  row that changes its header because of a neighbour is re-streamed with it.

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

  alias RetroHexChat.Accounts.Avatars
  alias RetroHexChat.Accounts.NickLocales
  alias RetroHexChat.Arcade
  alias RetroHexChat.Channels.ScheduledEvents
  alias RetroHexChat.Games.Results
  alias RetroHexChat.Scraper
  alias RetroHexChat.ShareLinks
  alias RetroHexChat.ShareLinks.Card
  alias RetroHexChatWeb.ChatLive.Components.DialogIsland
  alias RetroHexChatWeb.ChatLive.Components.MessageRow
  alias RetroHexChatWeb.ChatLive.Helpers.Session, as: SessionHelpers
  alias RetroHexChatWeb.ChatLive.MessageGrouping
  alias RetroHexChatWeb.ChatLive.ReadMarkers
  alias RetroHexChatWeb.ChatLive.StreamItem
  alias RetroHexChatWeb.ShareLinkRef

  use RetroHexChatWeb.ChatLive.Components.DialogIsland, id: "message-viewport"

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

  @doc "Appends or updates a single message row. Returns the socket."
  @spec insert(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def insert(socket, msg) do
    send_update(__MODULE__, id: @id, action: {:insert, msg})
    ReadMarkers.seen(socket, newest_id(socket, msg))
  end

  @doc """
  Refreshes a row **only if** the viewport is already showing it. Returns the socket.

  For a row that changed for a reason the reader did not cause on it — a reply
  landing under a message and moving its reply count. `insert/2` would be wrong
  there: a stream insert of an id the stream does not hold appends it, so a
  root that had scrolled out of the loaded page would reappear at the bottom,
  out of order, in the middle of a live conversation.
  """
  @spec insert_if_present(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def insert_if_present(socket, msg) do
    send_update(__MODULE__, id: @id, action: {:insert_if_present, msg})
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

    # A reset replaces the conversation, so what the viewport has shown is
    # replaced too — including with nothing. Carrying the previous
    # conversation's newest line across would move the wrong marker on the way
    # back out.
    ReadMarkers.replace_seen(
      socket,
      Enum.reduce(items, nil, fn item, acc -> newest(acc, Map.get(item, :id)) end)
    )
  end

  # An edit or a delete re-inserts a row that is not the newest one, so what the
  # viewport has shown only ever moves forward.
  @spec newest_id(Phoenix.LiveView.Socket.t(), map()) :: integer() | nil
  defp newest_id(socket, msg), do: newest(socket.assigns[:newest_message_id], Map.get(msg, :id))

  @spec newest(term(), term()) :: integer() | nil
  defp newest(current, id) when is_integer(current) and is_integer(id), do: max(current, id)
  defp newest(_current, id) when is_integer(id), do: id
  defp newest(current, _id), do: current

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
       timestamp_format: :hh_mm,
       timezone: "Etc/UTC",
       strip_formatting: false,
       edit_mode_message_id: nil,
       show_status_tab: false,
       loading_channel: nil,
       has_more: false,
       viewer: nil,
       show_avatars: true,
       unread_boundary_id: nil,
       rendered: [],
       share_card_spaces: MapSet.new(),
       scrollback?: false
     )
     |> stream(:chat_messages, [], limit: -@dom_limit)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:insert, msg}}, socket) do
    msg = decorate(socket, msg)

    case Enum.find(socket.assigns.rendered, &(&1.id == Map.get(msg, :id))) do
      nil ->
        msg = socket.assigns.rendered |> MessageGrouping.annotate_after([msg], tz(socket)) |> hd()

        {:ok,
         socket
         |> track(fn rendered -> upsert(rendered, msg) end)
         |> stream_insert(:chat_messages, msg, tail_opts(socket))
         |> restart_top()}

      old ->
        if MessageGrouping.regroup?(msg, old),
          do: {:ok, reflow(socket, &if(&1.id == msg.id, do: msg, else: &1))},
          else: {:ok, replace_rows(socket, [MessageGrouping.carry(msg, old)])}
    end
  end

  # `rendered` mirrors the stream, pruning included, so it is the honest answer
  # to "is this row on screen" — and the row is dropped rather than appended
  # when it is not.
  def update(%{action: {:insert_if_present, msg}}, socket) do
    if Enum.any?(socket.assigns.rendered, &(&1.id == Map.get(msg, :id))) do
      update(%{action: {:insert, msg}}, socket)
    else
      {:ok, socket}
    end
  end

  # Items arrive oldest-first; inserting reversed at position 0 lands them in
  # order above the existing rows (a load-more must never reset the stream —
  # ephemeral system lines are not in the DB and would vanish). No limit: see
  # the note on `@dom_limit` — a limit here deletes the page being inserted.
  #
  # The page is placed above the first row on screen, which keeps its band; if
  # what now sits above it takes away its header or its day label, it is
  # re-streamed in place.
  def update(%{action: {:prepend, items}}, socket) do
    {items, moved} =
      items
      |> decorate_all(viewer(socket))
      |> MessageGrouping.annotate_before(List.first(socket.assigns.rendered), tz(socket))

    socket =
      items
      |> Enum.reverse()
      |> Enum.reduce(
        socket
        |> assign(:scrollback?, true)
        |> track(fn rendered -> items ++ rendered end),
        &stream_insert(&2, :chat_messages, &1, at: 0)
      )

    {:ok, if(moved, do: replace_rows(socket, [moved]), else: socket)}
  end

  # The rows below a removed one are placed again against what is now above
  # them, and only the ones that moved are re-streamed.
  def update(%{action: {:delete, id}}, socket) do
    {:ok,
     socket
     |> stream_delete(:chat_messages, %{id: id})
     |> reflow(&if(&1.id == id, do: :removed, else: &1))}
  end

  # A reset is a new context — the scrollback the reader had loaded belongs to
  # the channel they left, so the cap comes back with it.
  #
  # The client is told, rather than left to infer it from the shape of the DOM
  # patch. A rebuilt list and a prepended page reach a MutationObserver as the
  # same thing (rows removed, rows added), and guessing between them throws a
  # reader paging through history down to the newest message.
  def update(%{action: {:reset, items}}, socket) do
    items = items |> decorate_all(viewer(socket)) |> MessageGrouping.annotate_all(tz(socket))

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

  # A room changed, so the cards for it did. Only the rows carrying a link are
  # re-resolved, and only the ones whose card actually moved are re-streamed:
  # a conference nobody joined must not repaint a screenful of messages, and a
  # reset would throw a reader in the middle of a scrollback down to the newest
  # line to say that somebody entered a call.
  def update(%{action: :refresh_share_cards}, socket) do
    {:ok, refresh_share_cards(socket)}
  end

  # Re-streaming what is already held is what makes a presentation change cost
  # nothing at the database. The limit is the number of rows being re-streamed,
  # so restyling a loaded scrollback cannot silently shorten it.
  #
  # The timezone is part of the presentation, so the runs and day breaks are
  # placed again.
  def update(%{action: :restyle}, socket) do
    rendered = MessageGrouping.annotate_all(socket.assigns.rendered, tz(socket))

    {:ok,
     socket
     |> assign(:rendered, rendered)
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
      :viewer,
      :show_avatars,
      :unread_boundary_id
    ]

    merged = DialogIsland.known(socket, assigns, keys)

    {:ok, assign(socket, merged)}
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
            show_avatars={@show_avatars}
            unread_boundary_id={@unread_boundary_id}
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

    socket
    |> assign(rendered: rendered)
    |> announce_share_card_spaces()
  end

  # An arriving message drops the oldest row once the tail is full, and drops
  # nothing at all once the reader has paged back.
  @spec tail_opts(Phoenix.LiveView.Socket.t()) :: keyword()
  defp tail_opts(%{assigns: %{scrollback?: true}}), do: []
  defp tail_opts(_socket), do: [limit: -@dom_limit]

  # ── Live share cards ───────────────────────────────────────

  @spec refresh_share_cards(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp refresh_share_cards(socket) do
    carrying = Enum.filter(socket.assigns.rendered, &is_map(Map.get(&1, :share_card)))

    described =
      carrying
      |> Enum.map(& &1.share_card.slug)
      |> ShareLinks.describe_many()

    changed =
      carrying
      |> Enum.map(&{&1, keep_creator_locale(Map.get(described, &1.share_card.slug), &1)})
      |> Enum.filter(fn {msg, card} -> is_map(card) and card != msg.share_card end)
      |> Enum.map(fn {msg, card} -> Map.put(msg, :share_card, card) end)

    replace_rows(socket, changed)
  end

  # A card described again is the same person's: the flag looked up with the
  # page stays, rather than a lookup per refresh.
  defp keep_creator_locale(card, msg) when is_map(card),
    do: Map.put(card, :creator_locale, Map.get(msg.share_card, :creator_locale))

  defp keep_creator_locale(card, _msg), do: card

  # The chat owns the subscriptions, because a subscription outlives a render.
  # It is told which spaces are on screen and does the arithmetic; saying it
  # from here is what makes "only while a card is visible" true rather than a
  # sentence in a plan.
  @spec announce_share_card_spaces(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp announce_share_card_spaces(socket) do
    spaces =
      socket.assigns.rendered
      |> Enum.map(&Map.get(&1, :share_card))
      |> Enum.filter(&match?(%{kind: "space"}, &1))
      |> Enum.map(&Map.get(&1.target, "space_id"))
      |> Enum.filter(&is_binary/1)
      |> MapSet.new()

    if spaces == socket.assigns[:share_card_spaces] do
      socket
    else
      send(self(), {:share_card_spaces, spaces})
      assign(socket, share_card_spaces: spaces)
    end
  end

  # ── Speaker runs ───────────────────────────────────────────

  defp tz(socket), do: socket.assigns[:timezone] || "Etc/UTC"

  # One row on screen changed what it is (deleted in place) or left: `change`
  # maps each row to itself, its replacement, or `:removed`. Every row from that
  # point down is placed again against what is now above it, and only the rows
  # that came out different are re-streamed.
  @spec reflow(Phoenix.LiveView.Socket.t(), (map() -> map() | :removed)) ::
          Phoenix.LiveView.Socket.t()
  defp reflow(socket, change) do
    rendered = socket.assigns.rendered
    index = Enum.find_index(rendered, &(change.(&1) != &1)) || length(rendered)
    {above, from} = Enum.split(rendered, index)
    changed = from |> Enum.map(change) |> Enum.reject(&(&1 == :removed))
    placed = MessageGrouping.annotate_after(above, changed, tz(socket))

    moved =
      placed
      |> Enum.reject(fn row -> Enum.find(from, &(&1.id == row.id)) == row end)

    socket
    |> track(fn _rendered -> above ++ placed end)
    |> replace_rows(moved)
    |> restart_top()
  end

  # The first row on screen opens a run and says its day. After the oldest row
  # is pruned off the tail, the new first row may have been a continuation.
  @spec restart_top(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  defp restart_top(socket) do
    case socket.assigns.rendered do
      [top | _] ->
        restarted = MessageGrouping.restart(top, tz(socket))
        if restarted == top, do: socket, else: replace_rows(socket, [restarted])

      [] ->
        socket
    end
  end

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
  # `:system` is on the list because a session's door is a system message: the
  # room's address is written into the channel by the server, not by a person,
  # and a card is the whole reason that line exists.
  @card_types [:message, :action, :system]
  @card_formats ["irc", "plain"]

  @spec decorate(Phoenix.LiveView.Socket.t(), map()) :: map()
  defp decorate(socket, msg), do: msg |> List.wrap() |> decorate_all(viewer(socket)) |> hd()

  defp viewer(socket), do: socket.assigns[:viewer]

  @spec decorate_all([map()], String.t() | nil) :: [map()]
  defp decorate_all([], _viewer), do: []

  defp decorate_all(items, viewer) do
    items = Enum.map(items, &tag_link/1)

    cards =
      items
      |> Enum.map(&Map.get(&1, :link_preview_hash))
      |> Enum.reject(&is_nil/1)
      |> Scraper.cards()

    items
    |> Enum.map(&put_card(&1, cards))
    |> put_share_cards()
    |> put_event_cards(viewer)
    |> put_result_cards()
    |> put_avatars()
    |> put_locales()
  end

  # The ids of the rows written in one kind of conversation. Channel lines and
  # private lines are numbered apart, so anything resolved by a line's id asks
  # with the ids of its own kind only.
  @spec ids_from([map()], :channel | :private) :: [integer()]
  defp ids_from(items, source) do
    for %{source: ^source, id: id} when is_integer(id) <- items, do: id
  end

  # A match's card hangs off the line that announced it, in the game's channel
  # or in the players' conversation — one query per kind, per screenful. The
  # card is found by the line's id, whoever wrote it, so a card outlives the
  # bot that announced it. In a conversation only a P2P system line carries
  # one, so a screenful of plain private lines asks nothing.
  @spec put_result_cards([map()]) :: [map()]
  defp put_result_cards(items) do
    cards = %{
      channel: Results.cards_for_messages(:channel, ids_from(items, :channel)),
      private:
        Results.cards_for_messages(:private, ids_from(Enum.filter(items, &p2p_line?/1), :private))
    }

    cards = put_player_locales(cards)
    plays = items |> ids_from(:channel) |> Arcade.play_cards_for_messages() |> put_play_locales()

    Enum.map(items, fn item ->
      item = put_play_card(item, plays)

      case get_in(cards, [Map.get(item, :source) || :none, Map.get(item, :id)]) do
        nil -> item
        card -> Map.put(item, :result_card, card)
      end
    end)
  end

  # An arcade game somebody started hangs its card off the line that said so,
  # in the game's channel or in `#arcade`, found the same way as a match's.
  defp put_play_card(%{source: :channel, id: id} = item, plays) do
    case Map.get(plays, id) do
      nil -> item
      card -> Map.put(item, :play_card, card)
    end
  end

  defp put_play_card(item, _plays), do: item

  defp put_play_locales(plays) when plays == %{}, do: plays

  defp put_play_locales(plays) do
    locales = plays |> Map.values() |> Enum.map(& &1.nickname) |> NickLocales.for_nicks()

    Map.new(plays, fn {id, card} ->
      {id, Map.put(card, :locale, Map.get(locales, card.nickname))}
    end)
  end

  # The flag beside each player on a match card: one lookup for every card on
  # the screenful, and none when there is no card.
  defp put_player_locales(cards) do
    players =
      for {_kind, by_id} <- cards,
          {_id, card} <- by_id,
          nick <- [card.p1_nickname, card.p2_nickname],
          is_binary(nick),
          uniq: true,
          do: nick

    locales = NickLocales.for_nicks(players)

    Map.new(cards, fn {kind, by_id} ->
      {kind,
       Map.new(by_id, fn {id, card} ->
         {id,
          Map.merge(card, %{
            p1_locale: Map.get(locales, card.p1_nickname),
            p2_locale: Map.get(locales, card.p2_nickname)
          })}
       end)}
    end)
  end

  defp p2p_line?(%{type: type}), do: type == :p2p_system
  defp p2p_line?(_line), do: false

  # Whose face goes beside each nickname, one query for the whole batch. Every
  # row reaches here — a page, a prepended page and a single arriving message —
  # so this is the one place that has to know.
  @spec put_avatars([map()]) :: [map()]
  defp put_avatars(items) do
    avatars =
      items |> Enum.map(&Map.get(&1, :author)) |> Enum.filter(&is_binary/1) |> Avatars.for_nicks()

    Enum.map(items, &StreamItem.put_avatar(&1, Map.get(avatars, Map.get(&1, :author))))
  end

  # The flag beside each nickname, for the same batch and for the same reason —
  # the authors, whoever they answer, and whoever shared a card they posted.
  @spec put_locales([map()]) :: [map()]
  defp put_locales(items) do
    locales =
      items
      |> Enum.flat_map(&[Map.get(&1, :author), Map.get(&1, :reply_to_author), share_creator(&1)])
      |> Enum.filter(&is_binary/1)
      |> NickLocales.for_nicks()

    Enum.map(items, fn item ->
      item
      |> StreamItem.put_locale(Map.get(locales, Map.get(item, :author)))
      |> StreamItem.put_reply_locale(Map.get(locales, Map.get(item, :reply_to_author)))
      |> put_creator_locale(locales)
    end)
  end

  defp share_creator(%{share_card: %{creator_nick: nick}}), do: nick
  defp share_creator(_item), do: nil

  defp put_creator_locale(%{share_card: %{creator_nick: nick} = card} = item, locales)
       when is_binary(nick),
       do: Map.put(item, :share_card, Map.put(card, :creator_locale, Map.get(locales, nick)))

  defp put_creator_locale(item, _locales), do: item

  # An event card hangs off the line that announced it, resolved by message id
  # rather than by reading the text — the announcement is an ordinary message
  # and the calendar entry is what knows it announced anything. One query for
  # the cards and one for this reader's own answers, per screenful.
  @spec put_event_cards([map()], String.t() | nil) :: [map()]
  defp put_event_cards(items, viewer) do
    cards = items |> ids_from(:channel) |> ScheduledEvents.cards_for_messages()

    if map_size(cards) == 0 do
      items
    else
      going =
        ScheduledEvents.attending_many(viewer || "", Enum.map(Map.values(cards), & &1.event_id))

      Enum.map(items, &put_event_card(&1, cards, going))
    end
  end

  @spec put_event_card(map(), map(), MapSet.t()) :: map()
  defp put_event_card(%{source: :channel} = item, cards, going) do
    case Map.get(cards, Map.get(item, :id)) do
      nil ->
        item

      card ->
        item
        |> Map.put(:event_card, card)
        |> Map.put(:event_attending, MapSet.member?(going, card.event_id))
    end
  end

  defp put_event_card(item, _cards, _going), do: item

  # A link into this app resolves against the database rather than the scraper:
  # there is nothing to fetch, and the answer is a room's state rather than a
  # page's title. One query for the whole screenful, and reading it never counts
  # as somebody following the link.
  @spec put_share_cards([map()]) :: [map()]
  defp put_share_cards(items) do
    tagged = Enum.map(items, &tag_share_link/1)

    described =
      tagged
      |> Enum.flat_map(&Map.get(&1, :share_slugs, []))
      |> ShareLinks.describe_many()

    Enum.map(tagged, fn item ->
      case Enum.find_value(Map.get(item, :share_slugs, []), &Map.get(described, &1)) do
        nil -> Map.delete(item, :share_slugs)
        resolution -> item |> Map.delete(:share_slugs) |> Map.put(:share_card, resolution)
      end
    end)
  end

  defp tag_share_link(%{type: :p2p_invite} = msg) do
    # The invite is the one card whose address was never minted: the session's
    # own token is the invitation. It resolves here rather than through the
    # slug query, and draws the same card.
    case ShareLinkRef.p2p_token_in(Map.get(msg, :content, "")) do
      nil -> msg
      token -> Map.put(msg, :share_card, Card.for_session(token))
    end
  end

  defp tag_share_link(msg) do
    if previewable?(msg) do
      Map.put(msg, :share_slugs, ShareLinkRef.slugs_in(msg.content))
    else
      msg
    end
  end

  # The fingerprint is recorded even when the archive has nothing yet: it is what
  # lets a page that lands later find the rows waiting for it.
  @spec tag_link(map()) :: map()
  defp tag_link(msg) do
    with true <- previewable?(msg),
         [url | _rest] <- scrapable_urls(msg),
         url_hash when is_binary(url_hash) <- Scraper.fingerprint(url) do
      Map.put(msg, :link_preview_hash, url_hash)
    else
      _ -> msg
    end
  end

  # A link into this app is not scraped. It draws its own card from the
  # database, and letting the scraper fetch our own page as well put two cards
  # under one message — one of them describing the site rather than the room.
  # A message that also carries somebody else's link still gets that preview.
  defp scrapable_urls(msg) do
    ours = ShareLinkRef.slugs_in(msg.content)

    msg.content
    |> SessionHelpers.extract_content_urls(card_format(msg))
    |> Enum.reject(fn url -> Enum.any?(ours, &String.contains?(url, "/join/" <> &1)) end)
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

      replace_rows(socket, decorated)
    else
      _ -> socket
    end
  end

  # Rows already on screen, drawn again in place: the mirror and the stream
  # change together.
  defp replace_rows(socket, msgs) do
    socket
    |> track(fn rendered -> Enum.reduce(msgs, rendered, &upsert(&2, &1)) end)
    |> then(&Enum.reduce(msgs, &1, fn msg, acc -> stream_insert(acc, :chat_messages, msg) end))
  end
end

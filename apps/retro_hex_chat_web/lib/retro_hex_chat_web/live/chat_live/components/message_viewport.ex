defmodule RetroHexChatWeb.ChatLive.Components.MessageViewport do
  @moduledoc """
  The main chat message viewport. Owns the `:chat_messages` stream and renders one
  `MessageRow` per message, so the message list re-renders only when a message is
  added, changed or removed — not on every parent re-render (typing, lag, sidebar
  churn). The per-row markup lives in the pure `MessageRow` function component.

  The parent stays the canonical owner of all pagination/scroll state
  (`oldest_message_id`, `has_more`, `loaded_message_count`, `loading_more`,
  `chat_clear_token`, `cleared_channel_cutoffs`) and of the message-production
  logic (commands, PubSub
  inserts, edits/deletes, load-more pagination, pending reconciliation, cleared-
  channel checks). Wherever that logic would mutate the stream it instead pushes a
  delta here via `send_update/2`:

    * `insert/2` — append or update a single message row
    * `delete/2` — remove a row by message id
    * `reset/2`  — replace the whole list (channel/PM switch, load-more, clear)

  Context (`chat_clear_token`, `nick_color_fn`, `timestamp_format`, `timezone`,
  `strip_formatting`, `edit_mode_message_id`, `show_status_tab`) is supplied by the
  parent each render. The `ScrollHook` and `MessageInteractionsHook` live on the
  list container and push to the parent LiveView, which holds the scroll/pagination
  state they drive.

  The channel-load spinner (`loading_channel`) and the load-older indicator
  (`loading_more`) render here too, co-located with the messages they describe. Both
  flags stay parent-owned (the load-more handler reads `loading_more` to debounce
  pagination; the channel switch sets/clears `loading_channel`) and are passed
  through each render — only their visuals live in this component.
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.ActivityIndicator
  import RetroHexChatWeb.Components.UI.ListStates

  alias RetroHexChatWeb.ChatLive.Components.MessageRow

  @id "message-viewport"

  # Three pages of scrollback stay in the DOM; older rows are dropped as the
  # reader keeps going. Without a cap, paging back through a long history grows
  # the document without bound.
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
       loading_more: false,
       has_more: false,
       loading_channel: nil,
       viewer: nil,
       rendered: []
     )
     |> stream(:chat_messages, [], limit: -@dom_limit)}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:insert, msg}}, socket) do
    {:ok,
     socket
     |> track(fn rendered -> upsert(rendered, msg) end)
     |> stream_insert(:chat_messages, msg, limit: -@dom_limit)}
  end

  # Items arrive oldest-first; inserting reversed at position 0 lands them in
  # order above the existing rows (a load-more must never reset the stream —
  # ephemeral system lines are not in the DB and would vanish).
  def update(%{action: {:prepend, items}}, socket) do
    socket = track(socket, fn rendered -> items ++ rendered end)

    {:ok,
     items
     |> Enum.reverse()
     |> Enum.reduce(socket, &stream_insert(&2, :chat_messages, &1, at: 0, limit: -@dom_limit))}
  end

  def update(%{action: {:delete, id}}, socket) do
    {:ok,
     socket
     |> track(fn rendered -> Enum.reject(rendered, &(&1.id == id)) end)
     |> stream_delete(:chat_messages, %{id: id})}
  end

  def update(%{action: {:reset, items}}, socket) do
    {:ok,
     socket
     |> track(fn _rendered -> items end)
     |> stream(:chat_messages, items, reset: true, limit: -@dom_limit)}
  end

  # Re-streaming what is already held is what makes a presentation change cost
  # nothing at the database.
  def update(%{action: :restyle}, socket) do
    {:ok,
     stream(socket, :chat_messages, socket.assigns.rendered, reset: true, limit: -@dom_limit)}
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
      :loading_more,
      :has_more,
      :loading_channel,
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

      <.activity_indicator
        :if={@loading_more}
        icon={:clock}
        text={dgettext("chat", "Loading older messages...")}
        class="message-viewport__scroll-loader"
        data-testid="scroll-loader"
      />

      <%!-- Closes the scrollback. Without it the top of a fully-loaded history
            is indistinguishable from a page that never arrived, which is the
            state the reader waits at forever. --%>
      <.list_end_marker
        :if={history_complete?(assigns)}
        text={dgettext("chat", "Beginning of history")}
        class="message-viewport__end-marker"
        testid="chat-history-end"
      />

      <.chat_message_list
        id="chat-messages"
        fill
        hidden={@show_status_tab}
        phx-update="stream"
        phx-hook="ScrollHook"
        data-clear-token={@chat_clear_token}
        data-interactions-hook="MessageInteractionsHook"
      >
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
      </.chat_message_list>
    </div>
    """
  end

  # The scrollback is complete when the server has nothing older, there is
  # something on screen for the marker to close, and no load is in flight —
  # otherwise "beginning of history" would appear over an empty or still-filling
  # viewport and read as a failure rather than an ending.
  @spec history_complete?(map()) :: boolean()
  defp history_complete?(assigns) do
    not assigns.has_more and not assigns.loading_more and
      is_nil(assigns.loading_channel) and assigns.rendered != []
  end

  # The rows currently on screen, kept alongside the stream because a stream
  # cannot be read back. Trimmed to the same cap as the DOM, from the same end,
  # so the two never disagree about what is rendered.
  @spec track(Phoenix.LiveView.Socket.t(), ([map()] -> [map()])) :: Phoenix.LiveView.Socket.t()
  defp track(socket, fun) do
    rendered = socket.assigns.rendered |> fun.() |> Enum.take(-@dom_limit)
    assign(socket, rendered: rendered)
  end

  @spec upsert([map()], map()) :: [map()]
  defp upsert(rendered, msg) do
    case Enum.find_index(rendered, &(&1.id == msg.id)) do
      nil -> rendered ++ [msg]
      index -> List.replace_at(rendered, index, msg)
    end
  end
end

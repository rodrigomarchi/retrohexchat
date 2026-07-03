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

  alias RetroHexChatWeb.ChatLive.Components.MessageRow

  @id "message-viewport"

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
       loading_channel: nil
     )
     |> stream(:chat_messages, [])}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:insert, msg}}, socket) do
    {:ok, stream_insert(socket, :chat_messages, msg)}
  end

  # Items arrive oldest-first; inserting reversed at position 0 lands them in
  # order above the existing rows (a load-more must never reset the stream —
  # ephemeral system lines are not in the DB and would vanish).
  def update(%{action: {:prepend, items}}, socket) do
    {:ok,
     items
     |> Enum.reverse()
     |> Enum.reduce(socket, &stream_insert(&2, :chat_messages, &1, at: 0))}
  end

  def update(%{action: {:delete, id}}, socket) do
    {:ok, stream_delete(socket, :chat_messages, %{id: id})}
  end

  def update(%{action: {:reset, items}}, socket) do
    {:ok, stream(socket, :chat_messages, items, reset: true)}
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
      :loading_channel
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
        class="mx-auto my-retro-12"
        text={
          dgettext("chat", "Loading %{channel}...",
            channel: @loading_channel || dgettext("chat", "messages")
          )
        }
        data-testid="channel-loader"
      />

      <.activity_indicator
        :if={@loading_more}
        icon={:clock}
        text={dgettext("chat", "Loading older messages...")}
        class="justify-center py-retro-8"
        data-testid="scroll-loader"
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
        />
      </.chat_message_list>
    </div>
    """
  end
end

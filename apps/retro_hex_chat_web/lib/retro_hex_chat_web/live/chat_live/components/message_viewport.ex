defmodule RetroHexChatWeb.ChatLive.Components.MessageViewport do
  @moduledoc """
  The main chat message viewport. Owns the `:chat_messages` stream and renders one
  row per message, so the message list re-renders only when a message is added,
  changed or removed — not on every parent re-render (typing, lag, sidebar churn).

  The parent stays the canonical owner of all pagination/scroll/pending state
  (`oldest_message_id`, `has_more`, `loaded_message_count`, `loading_more`,
  `new_messages_indicator`, `chat_clear_token`, `pending_channel_msg_id`,
  `cleared_channel_cutoffs`) and of the message-production logic (commands, PubSub
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
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.MessageReplyBlock
  import RetroHexChatWeb.Components.UI.InlineHelpCard
  import RetroHexChatWeb.Components.UI.P2PInviteCard
  import RetroHexChatWeb.Components.UI.ArcadeSessionLink
  import RetroHexChatWeb.Components.UI.MessageIndicators

  alias RetroHexChatWeb.App.ChatHelpers

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
       show_status_tab: false
     )
     |> stream(:chat_messages, [])}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(%{action: {:insert, msg}}, socket) do
    {:ok, stream_insert(socket, :chat_messages, msg)}
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
      :show_status_tab
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
      <.chat_message_list
        id="chat-messages"
        fill
        hidden={@show_status_tab}
        phx-update="stream"
        phx-hook="ScrollHook"
        data-clear-token={@chat_clear_token}
        data-interactions-hook="MessageInteractionsHook"
      >
        <div
          :for={{dom_id, msg} <- @streams.chat_messages}
          id={dom_id}
          class={message_classes(msg, @edit_mode_message_id)}
          data-testid={if(Map.get(msg, :highlighted), do: "highlighted-message", else: nil)}
          data-author={Map.get(msg, :author)}
          data-message-id={dom_id}
          data-temp-id={if(Map.get(msg, :status) in [:pending, :failed], do: msg.id, else: nil)}
          data-msg-status={if(Map.get(msg, :status), do: Atom.to_string(msg.status), else: nil)}
          data-system-message={
            if(
              Map.get(msg, :type, :normal) in [:system, :service, :inline_help, :arcade_link],
              do: "true",
              else: nil
            )
          }
          data-real-id={Map.get(msg, :id)}
        >
          <.render_message
            msg={msg}
            nick_color_fn={@nick_color_fn}
            timestamp_format={@timestamp_format}
            timezone={@timezone}
            strip_formatting={@strip_formatting}
            edit_mode_message_id={@edit_mode_message_id}
          />
        </div>
      </.chat_message_list>
    </div>
    """
  end

  attr :msg, :map, required: true
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, required: true
  attr :timezone, :string, required: true
  attr :strip_formatting, :boolean, required: true
  attr :edit_mode_message_id, :any, required: true

  defp render_message(assigns) do
    ~H"""
    <%= case Map.get(@msg, :type, :normal) do %>
      <% :action -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="action"
        >
          * {@msg.author} {raw(ChatHelpers.format_content(@msg.content, @strip_formatting))}
        </.chat_message>
      <% :system -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          * {@msg.content}
        </.chat_message>
      <% :service -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="service"
        >
          {@msg.content}
        </.chat_message>
      <% :error -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="error"
        >
          {@msg.content}
        </.chat_message>
      <% :notice -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="notice"
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
        >
          {@msg.content}
        </.chat_message>
      <% :inline_help -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          <.inline_help_card
            topic_id={@msg.topic_id}
            topic_title={@msg.topic_title}
            help_url={~p"/chat/help/#{@msg.topic_id}"}
          />
        </.chat_message>
      <% :arcade_link -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          type="system"
        >
          <.arcade_session_link href={@msg.content} />
        </.chat_message>
      <% :p2p_invite -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
        >
          <.p2p_invite_card
            label={ChatHelpers.extract_p2p_label(@msg.content)}
            link={ChatHelpers.extract_p2p_link(@msg.content)}
          />
        </.chat_message>
      <% _ -> %>
        <.message_reply_block
          :if={Map.get(@msg, :reply_to_id)}
          parent_id={@msg.reply_to_id}
          author={Map.get(@msg, :reply_to_author, "?")}
          preview={Map.get(@msg, :reply_to_preview)}
          nick_color={@nick_color_fn.(Map.get(@msg, :reply_to_author, ""))}
          on_click="scroll_to_reply_parent"
        />
        <%= if Map.get(@msg, :deleted_at) do %>
          <.chat_message timestamp={
            ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)
          }>
            <.deleted_placeholder />
          </.chat_message>
        <% else %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            nick={@msg.author}
            nick_color={@nick_color_fn.(@msg.author)}
          >
            {raw(ChatHelpers.format_content(@msg.content, @strip_formatting))}
            <.edited_tag
              :if={Map.get(@msg, :edited_at)}
              timestamp={ChatHelpers.format_edit_timestamp(@msg.edited_at, @timezone)}
            />
            <.retry_button
              :if={Map.get(@msg, :status) == :failed}
              temp_id={@msg.id}
              content={@msg.content}
              target={Map.get(@msg, :target, "")}
              on_retry="retry_message"
            />
          </.chat_message>
        <% end %>
    <% end %>
    """
  end

  @spec message_classes(map(), term()) :: String.t()
  defp message_classes(msg, edit_mode_message_id) do
    base = "chat-message chat-message--#{Map.get(msg, :type, :normal)}"

    highlighted = if Map.get(msg, :highlighted), do: " chat-message--highlighted", else: ""
    highlight_bg = ChatHelpers.highlight_bg_class(msg)
    pending = if Map.get(msg, :status) == :pending, do: " chat-message--pending", else: ""
    failed = if Map.get(msg, :status) == :failed, do: " chat-message--failed", else: ""
    deleted = if Map.get(msg, :deleted_at), do: " chat-message--deleted", else: ""

    editing =
      if Map.get(msg, :id) == edit_mode_message_id, do: " chat-message--editing", else: ""

    base <> highlighted <> highlight_bg <> pending <> failed <> deleted <> editing
  end
end

defmodule RetroHexChatWeb.ChatLive.Components.MessageRow do
  @moduledoc """
  Pure function component for a single streamed chat message row.

  Renders the row wrapper (the stream `dom_id`, the status/highlight CSS classes,
  and the `data-*` attributes the message-interaction hooks read) plus the body for
  each message type: normal, action, system, service, error, notice, inline-help,
  arcade-link, p2p-invite, deleted, edited, and failed-retry (with its reply block).

  Deterministic and side-effect free. It takes only the rendering context it needs
  (`nick_color_fn`, `timestamp_format`, `timezone`, `strip_formatting`,
  `edit_mode_message_id`) — never the full `Session` — so `MessageViewport` can
  render thousands of rows from its stream cheaply, without a LiveComponent per row.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.MessageReplyBlock
  import RetroHexChatWeb.Components.UI.InlineHelpCard
  import RetroHexChatWeb.Components.UI.P2PInviteCard
  import RetroHexChatWeb.Components.UI.ArcadeSessionLink
  import RetroHexChatWeb.Components.UI.MessageIndicators
  import RetroHexChatWeb.ChatLive.Components.SessionCard

  alias RetroHexChatWeb.App.ChatHelpers

  attr :dom_id, :string, required: true
  attr :msg, :map, required: true
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, required: true
  attr :timezone, :string, required: true
  attr :strip_formatting, :boolean, required: true
  attr :edit_mode_message_id, :any, required: true

  @doc "Renders one chat message row (wrapper + type-specific body) for the viewport stream."
  @spec message_row(map()) :: Phoenix.LiveView.Rendered.t()
  def message_row(assigns) do
    ~H"""
    <div
      id={@dom_id}
      class={message_classes(@msg, @edit_mode_message_id)}
      data-testid={if(Map.get(@msg, :highlighted), do: "highlighted-message", else: nil)}
      data-author={Map.get(@msg, :author)}
      data-message-id={@dom_id}
      data-temp-id={if(Map.get(@msg, :status) in [:pending, :failed], do: @msg.id, else: nil)}
      data-msg-status={if(Map.get(@msg, :status), do: Atom.to_string(@msg.status), else: nil)}
      data-system-message={
        if(
          Map.get(@msg, :type, :normal) in [:system, :service, :inline_help, :arcade_link],
          do: "true",
          else: nil
        )
      }
      data-real-id={Map.get(@msg, :id)}
    >
      <%= case Map.get(@msg, :type, :normal) do %>
        <% :action -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            type="action"
            nick={@msg.author}
            nick_color={@nick_color_fn.(@msg.author)}
          >
            * {raw(ChatHelpers.format_content(@msg.content, @strip_formatting))}
          </.chat_message>
        <% :system -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            source={dgettext("chat", "System")}
            type="system"
          >
            * {@msg.content}
          </.chat_message>
        <% :service -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            source={dgettext("chat", "Service")}
            type="service"
          >
            {@msg.content}
          </.chat_message>
        <% :error -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            source={dgettext("chat", "Error")}
            type="error"
          >
            {@msg.content}
          </.chat_message>
        <% :notice -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            type="notice"
            nick={@msg.author}
            nick_color={@nick_color_fn.(@msg.author)}
          >
            {@msg.content}
          </.chat_message>
        <% :announcement -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            source={dgettext("chat", "Server")}
            type="announcement"
          >
            {raw(ChatHelpers.format_content(@msg.content, @strip_formatting))}
          </.chat_message>
        <% :inline_help -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            source={dgettext("chat", "Help")}
            type="system"
            kind="help"
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
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            source={dgettext("chat", "Arcade")}
            type="system"
            kind="arcade"
          >
            <.session_card
              :if={Map.get(@msg, :session_card)}
              card={@msg.session_card}
              timezone={@timezone}
            />
            <.arcade_session_link :if={!Map.get(@msg, :session_card)} href={@msg.content} />
          </.chat_message>
        <% :p2p_invite -> %>
          <.chat_message
            timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
            meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
            nick={@msg.author}
            nick_color={@nick_color_fn.(@msg.author)}
          >
            <.session_card
              :if={Map.get(@msg, :session_card)}
              card={@msg.session_card}
              timezone={@timezone}
            />
            <.p2p_invite_card
              :if={!Map.get(@msg, :session_card)}
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
            <.chat_message
              timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
              meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
              source={dgettext("chat", "Deleted")}
              kind="deleted"
            >
              <.deleted_placeholder />
            </.chat_message>
          <% else %>
            <.chat_message
              timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
              meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
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
    </div>
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

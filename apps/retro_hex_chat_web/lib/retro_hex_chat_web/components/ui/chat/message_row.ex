defmodule RetroHexChatWeb.Components.UI.MessageRow do
  @moduledoc """
  Visual body composition for a streamed chat message row.

  The Live layer owns the stream wrapper and data attributes used by JS hooks.
  This component owns the type-specific message presentation.
  """
  use RetroHexChatWeb.Component

  import Phoenix.HTML, only: [raw: 1]
  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.InlineHelpCard
  import RetroHexChatWeb.Components.UI.MessageIndicators
  import RetroHexChatWeb.Components.UI.MessageReplyBlock
  import RetroHexChatWeb.Components.UI.P2PInviteCard
  import RetroHexChatWeb.Components.UI.SessionCard

  alias RetroHexChatWeb.App.ChatHelpers

  attr :msg, :map, required: true
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, required: true
  attr :timezone, :string, required: true
  attr :strip_formatting, :boolean, required: true
  attr :viewer, :string, default: nil, doc: "Viewing user's nickname (P2P invite cards)"

  @spec message_row_body(map()) :: Phoenix.LiveView.Rendered.t()
  def message_row_body(assigns) do
    ~H"""
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
      <% :p2p_system -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "P2P")}
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
            help_url={help_url(@msg.topic_id)}
          />
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
            viewer={@viewer}
          />
          <.p2p_invite_card
            :if={!Map.get(@msg, :session_card)}
            label={ChatHelpers.extract_p2p_label(@msg.content)}
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
    """
  end

  defp help_url(topic_id), do: "/chat/help/#{topic_id}"
end

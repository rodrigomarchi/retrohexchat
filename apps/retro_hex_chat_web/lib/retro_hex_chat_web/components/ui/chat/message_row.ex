defmodule RetroHexChatWeb.Components.UI.MessageRow do
  @moduledoc """
  Visual body composition for a streamed chat message row.

  The Live layer owns the stream wrapper and data attributes used by JS hooks.
  This component owns the type-specific message presentation.

  Every type renders its text through `ChatHelpers.format_content/3`. That is
  the only thing that turns persisted chat formats into markup, and a type that
  interpolates its content directly does not print IRC control bytes plain — the
  browser swallows the control byte and leaves the colour's digits behind as text
  ("06 [Wanda]"). It is also what escapes the text and links its URLs, so
  routing everything through it is one rule, not five.
  """
  use RetroHexChatWeb.Component

  import Phoenix.HTML, only: [raw: 1]
  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.ChatAttachment
  import RetroHexChatWeb.Components.UI.InlineHelpCard
  import RetroHexChatWeb.Components.UI.MessageIndicators
  import RetroHexChatWeb.Components.UI.MessageReplyBlock

  alias RetroHexChatWeb.App.ChatHelpers

  attr :msg, :map, required: true
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, required: true
  attr :timezone, :string, required: true
  attr :strip_formatting, :boolean, required: true
  attr :viewer, :string, default: nil, doc: "Legacy caller compatibility"

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
          * {raw(formatted_content(@msg, @strip_formatting))}
        </.chat_message>
      <% :system -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "System")}
          type="system"
        >
          * {raw(formatted_content(@msg, @strip_formatting))}
        </.chat_message>
      <% :p2p_system -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "P2P")}
          type="system"
        >
          * {raw(formatted_content(@msg, @strip_formatting))}
        </.chat_message>
      <% :service -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "Service")}
          type="service"
        >
          {raw(formatted_content(@msg, @strip_formatting))}
        </.chat_message>
      <% :error -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "Error")}
          type="error"
        >
          {raw(formatted_content(@msg, @strip_formatting))}
        </.chat_message>
      <% :notice -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          type="notice"
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
        >
          {raw(formatted_content(@msg, @strip_formatting))}
        </.chat_message>
      <% :announcement -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "Server")}
          type="announcement"
        >
          {raw(formatted_content(@msg, @strip_formatting))}
        </.chat_message>
      <% :inline_help -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "Help")}
          type="system"
          kind="help"
          layout="stacked"
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
          source={dgettext("chat", "P2P")}
          type="system"
        >
          * {dgettext("chat", "P2P request")}
          <span class="text-muted-foreground">
            {dgettext("chat", "Use the P2P control in this private message.")}
          </span>
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
            {raw(formatted_content(@msg, @strip_formatting))}
            <.attachment_gallery attachments={Map.get(@msg, :attachments, [])} />
            <.edited_tag
              :if={Map.get(@msg, :edited_at)}
              timestamp={ChatHelpers.format_edit_timestamp(@msg.edited_at, @timezone)}
            />
            <.retry_button
              :if={Map.get(@msg, :status) == :failed}
              temp_id={@msg.id}
              content={@msg.content}
              content_format={Map.get(@msg, :content_format, "irc")}
              target={Map.get(@msg, :target, "")}
              on_retry="retry_message"
            />
          </.chat_message>
        <% end %>
    <% end %>
    """
  end

  defp help_url(topic_id), do: "/chat/help/#{topic_id}"

  defp formatted_content(msg, strip_formatting) do
    content = Map.get(msg, :content, "")
    content_format = Map.get(msg, :content_format, "irc")

    ChatHelpers.format_content(content, content_format, strip_formatting)
  end
end

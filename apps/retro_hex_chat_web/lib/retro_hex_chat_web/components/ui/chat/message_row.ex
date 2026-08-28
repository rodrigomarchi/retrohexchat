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
  import RetroHexChatWeb.Components.UI.ShareMessageCard

  alias RetroHexChat.Games.Catalog
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
          <.link_preview_card
            card={Map.get(@msg, :link_preview)}
            strip_formatting={@strip_formatting}
          />
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
            <.link_preview_card
              card={Map.get(@msg, :link_preview)}
              strip_formatting={@strip_formatting}
            />
            <%!-- A link into this app draws itself rather than being scraped:
                  the useful thing is the room's state, not a page title. --%>
            <.share_message_card
              :if={not @strip_formatting}
              card={Map.get(@msg, :share_card)}
              subject={share_subject(Map.get(@msg, :share_card))}
              enter_path={share_enter_path(Map.get(@msg, :share_card))}
            />
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

  attr :card, :string, default: nil
  attr :strip_formatting, :boolean, required: true

  # The link a message carried, as the card the RSS bot publishes for a feed item.
  #
  # Rendered as Markdown through the same helper as every other message body, so
  # it goes through the sanitiser that hardens the publisher's image. The reader
  # who asked for plain text gets plain text: `strip_formatting` suppresses the
  # card rather than flattening it, because a card without its layout is a
  # paragraph of duplicated link text.
  @spec link_preview_card(map()) :: Phoenix.LiveView.Rendered.t()
  defp link_preview_card(assigns) do
    ~H"""
    <div :if={@card && not @strip_formatting} class="chat-link-card">
      {raw(ChatHelpers.format_content(@card, "markdown", false))}
    </div>
    """
  end

  defp help_url(topic_id), do: "/chat/help/#{topic_id}"

  # Resolved here rather than in the viewport because the catalogue read is
  # cheap and pure, and the card is the only thing that wants it.
  defp share_subject(%{kind: "play", target: %{"game_id" => game_id}}) do
    case Catalog.get_game(game_id) do
      {:ok, game} -> Map.take(game, [:name, :tagline, :icon])
      {:error, :not_found} -> nil
    end
  end

  defp share_subject(_card), do: nil

  defp share_enter_path(%{slug: slug}) when is_binary(slug), do: "/join/#{slug}"
  defp share_enter_path(_card), do: nil

  defp formatted_content(msg, strip_formatting) do
    content = Map.get(msg, :content, "")
    content_format = Map.get(msg, :content_format, "irc")

    ChatHelpers.format_content(content, content_format, strip_formatting)
  end
end

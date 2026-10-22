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
  import RetroHexChatWeb.Components.UI.ArcadePlayCard
  import RetroHexChatWeb.Components.UI.ChatMessage
  import RetroHexChatWeb.Components.UI.ChatAttachment
  import RetroHexChatWeb.Components.UI.EventCard
  import RetroHexChatWeb.Components.UI.GameResultCard
  import RetroHexChatWeb.Components.UI.InlineHelpCard
  import RetroHexChatWeb.Components.UI.MessageIndicators
  import RetroHexChatWeb.Components.UI.MessageReactions
  import RetroHexChatWeb.Components.UI.MessageReplyBlock
  import RetroHexChatWeb.Components.UI.ShareMessageCard
  import RetroHexChatWeb.Components.UI.VisitorGreetingCard

  alias RetroHexChat.Chat.TimeFormatter
  alias RetroHexChat.Games.Catalog
  alias RetroHexChat.Nickname
  alias RetroHexChatWeb.App.ChatHelpers
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.PublicPages
  alias RetroHexChatWeb.ShareLinkRef

  attr :msg, :map, required: true
  attr :nick_color_fn, :any, required: true
  attr :timestamp_format, :atom, required: true
  attr :timezone, :string, required: true
  attr :strip_formatting, :boolean, required: true
  attr :viewer, :string, default: nil, doc: "whose reaction chips are drawn as pressed"
  attr :show_avatars, :boolean, default: true, doc: "whether character portraits are drawn"

  @spec message_row_body(map()) :: Phoenix.LiveView.Rendered.t()
  def message_row_body(assigns) do
    ~H"""
    <%= case Map.get(@msg, :type, :normal) do %>
      <% :action -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          type="action"
          layout={card_layout(@msg)}
          nick={@msg.author}
          nick_color={@nick_color_fn.(@msg.author)}
          locale={Map.get(@msg, :locale)}
          avatar={@show_avatars && Map.get(@msg, :avatar)}
        >
          * {raw(formatted_content(@msg, @strip_formatting))}
          <.link_preview_card
            card={Map.get(@msg, :link_preview)}
            strip_formatting={@strip_formatting}
          />
          <%!-- A `/me` line can carry a share link like any other line, and the
                viewport attaches the card to it; a row that then draws the bare
                address is the door made invisible. --%>
          <.share_card msg={@msg} strip_formatting={@strip_formatting} timezone={@timezone} />
        </.chat_message>
      <% :system -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "System")}
          type="system"
          layout={card_layout(@msg)}
        >
          * {raw(formatted_content(@msg, @strip_formatting))}
          <%!-- What the channel agreed to do, under the line that said so. The
                same reasoning as the session card: the line exists because of
                the thing, and a line without it is an announcement of nothing. --%>
          <.event_card
            card={Map.get(@msg, :event_card)}
            when_text={ChatHelpers.format_datetime(event_start(@msg), @timezone)}
            relative_text={event_relative(@msg)}
            attending={Map.get(@msg, :event_attending, false)}
            on_attend="event_attend"
            on_unattend="event_unattend"
            surface_path={event_surface_path(@msg)}
          />
          <%!-- A session's door is a system line: the server writes the room's
                address into the channel, and the card under it is the whole
                reason that line exists. Attaching the card without drawing it
                here is how the door came to be invisible while every test that
                built its own `:message` row stayed green. --%>
          <.share_card msg={@msg} strip_formatting={@strip_formatting} timezone={@timezone} />
        </.chat_message>
      <% :p2p_system -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "P2P")}
          type="system"
          layout={card_layout(@msg)}
        >
          <%!-- A match the two of you played is the card; the sentence it
                replaces is still there for whoever turned formatting off. --%>
          <span :if={is_nil(result_card(@msg, @strip_formatting))}>
            * {raw(formatted_content(@msg, @strip_formatting))}
          </span>
          <.game_result_card card={result_card(@msg, @strip_formatting)} />
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
          locale={Map.get(@msg, :locale)}
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
            help_url={PublicPages.help_topic_path(@msg.topic_id)}
          />
        </.chat_message>
      <% :visitor_greeting -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "System")}
          type="system"
          layout="stacked"
        >
          <.visitor_greeting_card server={@msg.server} guest={@msg.guest} channel={@msg.channel} />
        </.chat_message>
      <% :p2p_invite -> %>
        <.chat_message
          timestamp={ChatHelpers.format_time(@msg.timestamp, @timestamp_format, @timezone)}
          meta_title={ChatHelpers.format_datetime(@msg.timestamp, @timezone)}
          source={dgettext("chat", "P2P")}
          type="system"
          layout={card_layout(@msg)}
        >
          * {dgettext("chat", "P2P request")}
          <span :if={is_nil(Map.get(@msg, :share_card))} class="text-muted-foreground">
            {dgettext("chat", "Use the P2P control in this private message.")}
          </span>
          <%!-- The invite is a variant of the same card, not a second
                component: a session is a room like any other, and the line
                above it is the sentence a card cannot carry — who is asking. --%>
          <.share_card
            msg={@msg}
            strip_formatting={@strip_formatting}
            timezone={@timezone}
            invite?={true}
          />
        </.chat_message>
      <% _ -> %>
        <.message_reply_block
          :if={Map.get(@msg, :reply_to_id)}
          parent_id={@msg.reply_to_id}
          author={Map.get(@msg, :reply_to_author, "?")}
          preview={Map.get(@msg, :reply_to_preview)}
          nick_color={@nick_color_fn.(Map.get(@msg, :reply_to_author, ""))}
          locale={Map.get(@msg, :reply_to_locale)}
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
            locale={Map.get(@msg, :locale)}
            avatar={@show_avatars && Map.get(@msg, :avatar)}
            layout={card_layout(@msg)}
          >
            <span :if={is_nil(card_of(@msg, @strip_formatting))}>
              {raw(formatted_content(@msg, @strip_formatting))}
            </span>
            <%!-- A line the games service wrote about a match, in the game's
                  channel or in the one every game's results go to. --%>
            <.game_result_card card={result_card(@msg, @strip_formatting)} />
            <%!-- A line saying somebody started an arcade game, in the game's
                  channel or in #arcade. --%>
            <.arcade_play_card card={play_card(@msg, @strip_formatting)} />
            <.link_preview_card
              card={Map.get(@msg, :link_preview)}
              strip_formatting={@strip_formatting}
            />
            <%!-- A link into this app draws itself rather than being scraped:
                  the useful thing is the room's state, not a page title. --%>
            <.share_card msg={@msg} strip_formatting={@strip_formatting} timezone={@timezone} />
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
            <%!-- The cheapest answer there is, under the line it answers: the
                  chips, then the smiley that adds one, in the place the next
                  one will take. A row that failed to send has no id to react
                  to, so it gets no smiley. --%>
            <.message_reactions
              message_id={@msg.id}
              reactions={Map.get(@msg, :reactions)}
              source={Map.get(@msg, :source)}
              viewer={@viewer}
              pickable={reactable?(@msg)}
              author={@msg.author}
              on_toggle="toggle_reaction"
            />
            <%!-- What the line collected, said once under it. The replies stay
                  in the conversation where they were written — this only says
                  that they happened, so a small room never has to choose
                  between reading the room and reading the thread. --%>
            <.thread_tag
              message_id={@msg.id}
              count={Map.get(@msg, :reply_count, 0)}
              on_open="open_thread"
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

  # Only a stored message can carry a reaction. A row that failed to send keeps
  # a placeholder id ("pending_3") the database has never seen; a row still
  # pending already carries the id the server returned.
  @spec reactable?(map()) :: boolean()
  defp reactable?(msg), do: is_integer(msg.id)

  # A card is a block of its own and cannot ride the head line beside the
  # narration, so a row carrying one is stacked whatever its type would choose.
  defp card_layout(msg) do
    if Map.get(msg, :share_card) || Map.get(msg, :event_card) || Map.get(msg, :result_card) ||
         Map.get(msg, :play_card),
       do: "stacked",
       else: "auto"
  end

  # The match card stands in for the sentence about the match, except for the
  # reader who asked for plain text: they get the sentence.
  defp result_card(_msg, true = _strip_formatting), do: nil
  defp result_card(msg, _strip_formatting), do: Map.get(msg, :result_card)

  defp play_card(_msg, true = _strip_formatting), do: nil
  defp play_card(msg, _strip_formatting), do: Map.get(msg, :play_card)

  # Whichever games card stands in for the line's sentence.
  defp card_of(msg, strip_formatting),
    do: result_card(msg, strip_formatting) || play_card(msg, strip_formatting)

  attr :msg, :map, required: true
  attr :strip_formatting, :boolean, required: true
  attr :timezone, :string, required: true

  attr :invite?, :boolean,
    default: false,
    doc: "a P2P invite: its way in is the session itself, and it is not passed on"

  # The card a line's own link draws. The reader who asked for plain text gets
  # the address instead, which `without_card_address/3` leaves in place for them.
  defp share_card(%{invite?: true} = assigns) do
    ~H"""
    <.share_message_card
      :if={not @strip_formatting}
      card={Map.get(@msg, :share_card)}
      creator_locale={creator_locale(Map.get(@msg, :share_card), @msg)}
      enter_path={p2p_enter_path(Map.get(@msg, :share_card))}
      next_path={share_next_path(Map.get(@msg, :share_card))}
      ended_at_text={share_ended_at_text(Map.get(@msg, :share_card), @timezone)}
    />
    """
  end

  defp share_card(assigns) do
    assigns = assign(assigns, :card, Map.get(assigns.msg, :share_card))

    ~H"""
    <.share_message_card
      :if={not @strip_formatting}
      card={@card}
      creator_locale={creator_locale(@card, @msg)}
      subject={share_subject(@card)}
      enter_path={share_enter_path(@card)}
      share_url={share_url(@card)}
      next_path={share_next_path(@card)}
      watch_path={share_watch_path(@card)}
      ended_at_text={share_ended_at_text(@card, @timezone)}
    />
    """
  end

  # The card carries its sharer's flag, looked up with the page. Without it,
  # whoever shared the card wrote the line it hangs off, most of the time; then
  # the line's own flag is theirs, with nothing more to look up.
  defp creator_locale(%{creator_locale: locale}, _msg) when is_binary(locale), do: locale

  defp creator_locale(%{creator_nick: nick}, msg) when is_binary(nick) do
    if Nickname.equal?(nick, Map.get(msg, :author)), do: Map.get(msg, :locale)
  end

  defp creator_locale(_card, _msg), do: nil

  defp share_watch_path(%{watch?: true, target: %{"session_token" => token}})
       when is_binary(token),
       do: Paths.watch_path(token)

  defp share_watch_path(_card), do: nil

  defp event_start(msg) do
    case Map.get(msg, :event_card) do
      %{starts_at: starts_at} -> starts_at
      _no_card -> nil
    end
  end

  # Both readings of the instant come from the same place, so a card can never
  # show a clock time and a countdown that disagree.
  defp event_relative(msg) do
    case event_start(msg) do
      nil -> nil
      starts_at -> TimeFormatter.format_until(starts_at)
    end
  end

  # An event points at a place only when this product has one to open. A game
  # id names a game; "space" means the channel's own place, which the toolbar
  # already knows how to enter, so the card does not offer a second door to it.
  defp event_surface_path(msg) do
    case Map.get(msg, :event_card) do
      %{surface_hint: hint} when is_binary(hint) and hint != "" -> game_path(hint)
      _no_hint -> nil
    end
  end

  defp game_path(game_id) do
    case Catalog.get_game(game_id) do
      {:ok, game} -> Paths.play_path(game.id)
      {:error, :not_found} -> nil
    end
  end

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

  defp share_url(%{slug: slug}) when is_binary(slug), do: ShareLinkRef.url(slug)
  defp share_url(_card), do: nil

  # The session's own address, which is what the invite was carrying all along.
  defp p2p_enter_path(%{kind: "p2p", target: %{"session_token" => token}})
       when is_binary(token),
       do: Paths.p2p_path(token)

  defp p2p_enter_path(_card), do: nil

  # A card whose room has ended is a record, and a record is read rather than
  # followed. This card is only ever drawn inside the chat, so every "next" it
  # used to offer led where the reader already was — and following one cost
  # them the whole desktop, because navigating to the chat from the chat
  # re-mounts it. A match is the exception that shows the shape: a game is a
  # place in a catalogue rather than a room, and it is never where the reader
  # is standing.
  defp share_next_path(%{state: :ended, kind: "play", target: %{"game_id" => game_id}})
       when is_binary(game_id),
       do: Paths.play_path(game_id)

  defp share_next_path(_card), do: nil

  # The row's own timestamp belongs to the line, and the line is the room
  # *opening* — which leaves the record saying how long a gathering lasted and
  # nothing about when it stopped. Written in full rather than in the reader's
  # short clock: it is the one instant on the row that has no neighbouring date
  # to be read against, and `:none` timestamps would otherwise blank it.
  defp share_ended_at_text(%{metrics: %{ended_at: %DateTime{} = ended_at}}, timezone),
    do: ChatHelpers.format_datetime(ended_at, timezone)

  defp share_ended_at_text(_card, _timezone), do: nil

  defp formatted_content(msg, strip_formatting) do
    content = Map.get(msg, :content, "")
    content_format = Map.get(msg, :content_format, "irc")

    content
    |> without_card_address(msg, strip_formatting)
    |> ChatHelpers.format_content(content_format, strip_formatting)
  end

  # The card *is* the address, drawn: it names the room, counts who is inside
  # and carries both Join and Copy link. Printing the raw URL above it says the
  # same thing a third time, in the one shape a reader cannot act on.
  #
  # The address stays in the message — the card is derived from it, and a row
  # that draws no card still needs it — so it is dropped here, at the last
  # moment, and only when the card that replaces it is actually being drawn.
  defp without_card_address(content, msg, strip_formatting) do
    with false <- strip_formatting,
         url when is_binary(url) <- share_url(Map.get(msg, :share_card)) do
      content
      |> String.replace(url, "")
      |> String.trim()
      |> String.trim_trailing("—")
      |> String.trim()
    else
      _ -> content
    end
  end
end

defmodule RetroHexChatWeb.Components.UI.ShareMessageCard do
  @moduledoc """
  A shared link, drawn in the conversation as the room it names.

  Five kinds — a channel, a conference, a space, a game, a P2P session — and
  two states each. Live, it says who is in there and offers the way in beside
  the way to pass it on. The way in opens a tab of its own, because this card is
  the only door those rooms have and following a door must not close the
  conversation behind you.

  **Ended, it is a record and offers nothing.** It says what happened, when it
  stopped and who was there, and that is all — because this card is only ever
  drawn inside the chat, so every "next plausible thing" it used to offer led
  where the reader already was: a finished call pointed at the channel it was
  sitting in, everything else at the chat itself. Following one re-mounted the
  chat and cost the reader their open windows to arrive where they started. The
  one exception is a match, and it is not really an exception: a game is a place
  in a catalogue rather than a room, and it is never where the reader is.

  The card never names a channel the reader could not have found on their own.
  That decision is made in the domain (`ShareLinks.Card`, via
  `Channels.Visibility.nameable?/1`) and arrives here as a `channel_name` that
  is either there or `nil` — because a component that decided it would be a
  second copy of the rule, and the two would drift.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.ChatCard
  import RetroHexChatWeb.Components.UI.NickFlag

  alias RetroHexChatWeb.Components.UI.ShareKind
  alias RetroHexChatWeb.Icons

  attr :card, :map,
    default: nil,
    doc: "a `ShareLinks.Card`, or nil when the message carries no link of ours"

  attr :subject, :map, default: nil, doc: "%{name, tagline, icon} for what was shared"
  attr :enter_path, :string, default: nil
  attr :share_url, :string, default: nil, doc: "the address to hand on, for the Copy button"
  attr :next_path, :string, default: nil, doc: "where an ended card points instead of in"

  attr :watch_path, :string,
    default: nil,
    doc: "a taken seat's match, to watch — the one way on a full match offers"

  attr :ended_at_text, :string,
    default: nil,
    doc: "when the room stopped, already in the reader's timezone"

  attr :creator_locale, :string,
    default: nil,
    doc: "the locale of whoever shared the link, for their flag where the card names them"

  @spec share_message_card(map()) :: Phoenix.LiveView.Rendered.t()
  def share_message_card(assigns) do
    assigns =
      assigns
      |> assign(:ended?, ended?(assigns.card))
      |> assign(:next_label, next_label(assigns.subject, assigns.card))
      |> assign(:names_creator?, names_creator?(assigns.subject, assigns.card))

    ~H"""
    <%!-- A card that has ended is a record, not a dead control: the state is
          said by the badge word and its colour, the missing way in, and a
          detail written in the past tense — nothing on the card is dimmed. --%>
    <.chat_card
      :if={@card}
      layout={:row}
      data-testid="share-message-card"
      data-share-kind={@card.kind}
      data-share-state={state(@card)}
      data-share-count={@card[:count]}
      data-share-duration={metric(@card, :duration_seconds)}
      data-share-visitors={metric(@card, :visitors)}
    >
      <:icon>
        {apply(Icons, ShareKind.subject_icon(@subject, @card.kind), [%{class: "h-8 w-8"}])}
      </:icon>
      <:title>{heading(@subject, @card)}</:title>
      <:badge>
        <.chat_card_badge tone={if @ended?, do: :muted, else: :live} data-testid="share-message-state">
          {badge(@card)}
        </.chat_card_badge>
      </:badge>

      <%!-- The instant, on a line of its own. The row this card hangs under
            is stamped with the moment the door was written — the room
            *opening* — so a gathering that ran all afternoon said how long it
            lasted and nothing about when it stopped. Written in full because
            it is the one clock on the row with no neighbouring date to be
            read against, and kept out of the sentence below because that
            sentence is clamped and the ending would push the headcount off
            the end of it. --%>
      <span
        :if={@ended? and @ended_at_text}
        class="text-muted-foreground block"
        data-testid="share-message-ended-at"
      >
        {dgettext("share", "ended %{when}", when: @ended_at_text)}
      </span>
      <%!-- The heading truncates because a channel name has no length limit
            worth designing around. The detail must not: it is a short fixed
            sentence, and the half of it that got cut was the headcount the
            ended card exists to carry — "lasted less than a minute…" with the
            people silently gone. Two lines, and it always fits. --%>
      <span
        class="text-muted-foreground block line-clamp-2"
        data-testid="share-message-detail"
      >
        <.nick_flag :if={@names_creator?} locale={@creator_locale} />
        {detail(@subject, @card)}
      </span>

      <%!-- A card that has ended loses the way in: the room is not there to be
            entered, and a button that says Join and cannot is worse than no
            button. --%>
      <:actions :if={not @ended? and (@enter_path || @share_url)}>
        <.surface_link
          :if={@enter_path}
          as={:button}
          href={@enter_path}
          label={heading(@subject, @card)}
          data-testid="share-message-enter"
        >
          <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
          {dgettext("share", "Join")}
        </.surface_link>

        <.button
          :if={@share_url}
          type="button"
          size="sm"
          variant="outline"
          class="shrink-0"
          id={"share-card-copy-#{@card.slug}"}
          phx-hook="CopyValueHook"
          data-copy-text={@share_url}
          data-copied-label={dgettext("share", "Copied!")}
          data-testid="share-message-copy"
        >
          <:icon><Icons.icon_copy class="h-4 w-4" /></:icon>
          {dgettext("share", "Copy link")}
        </.button>
      </:actions>

      <%!-- A seat that was taken is a match being played; nobody can join
          it, anybody can watch it. --%>
      <:actions :if={@watch_path}>
        <.surface_link
          as={:button}
          href={@watch_path}
          label={heading(@subject, @card)}
          data-testid="share-message-watch"
        >
          <:icon><Icons.icon_watching class="h-4 w-4" /></:icon>
          {dpgettext("share", "match", "Watch")}
        </.surface_link>
      </:actions>

      <%!-- The label is required as well as the path, so a kind added later
            gets no button rather than somebody else's. It opens beside the
            chat, as every Play does: following it in this tab would take the
            conversation away. --%>
      <:actions :if={@ended? && @next_path && @next_label}>
        <.surface_link
          as={:button}
          href={@next_path}
          label={@next_label}
          variant="outline"
          data-testid="share-message-next"
        >
          <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
          {@next_label}
        </.surface_link>
      </:actions>
    </.chat_card>
    """
  end

  @doc "Whether this card describes something that is no longer running."
  @spec ended?(map() | nil) :: boolean()
  def ended?(%{state: :ended}), do: true
  def ended?(_card), do: false

  defp state(%{state: :ended}), do: "ended"
  defp state(_card), do: "live"

  # The heading names the channel only when the domain said it may be named;
  # otherwise it says what kind of room it is and nothing about which one.
  defp heading(subject, %{kind: "play"} = card), do: game_heading(subject, card)

  defp heading(_subject, %{kind: "call", channel_name: channel}) when is_binary(channel),
    do: dgettext("share", "Call in %{channel}", channel: channel)

  defp heading(_subject, %{kind: "space", channel_name: channel}) when is_binary(channel),
    do: dgettext("share", "Space of %{channel}", channel: channel)

  # A channel is its own name and needs no sentence around it. Without this the
  # card fell through to "An invitation" and never said which room it led to,
  # however public that room was — while the domain had been carrying the name
  # and the headcount all along.
  defp heading(_subject, %{kind: "channel", channel_name: channel}) when is_binary(channel),
    do: channel

  defp heading(%{name: name}, _card) when is_binary(name), do: name
  defp heading(_subject, %{kind: "call"}), do: dgettext("share", "A conference")
  defp heading(_subject, %{kind: "space"}), do: dgettext("share", "A virtual space")
  defp heading(_subject, %{kind: "p2p"}), do: dgettext("share", "P2P session")
  defp heading(_subject, _card), do: dgettext("share", "An invitation")

  defp game_heading(%{name: name}, _card) when is_binary(name), do: name
  defp game_heading(_subject, _card), do: dgettext("share", "A game")

  # The badge is the one word that says whether this is happening now.
  defp badge(%{state: :ended, reason: :full}), do: dgettext("share", "Taken")
  defp badge(%{state: :ended, reason: :revoked}), do: dgettext("share", "Closed")
  defp badge(%{state: :ended, reason: :expired}), do: dgettext("share", "Expired")
  defp badge(%{state: :ended}), do: dgettext("share", "Over")
  defp badge(%{kind: "play"}), do: dgettext("share", "Waiting")
  defp badge(_card), do: dgettext("share", "Live")

  # A live card counts, and names up to three. An ended one is the record of
  # what happened: how long it ran and how many people were in it, which is the
  # question somebody scrolling past an old card is actually asking. Only the
  # kinds that end have that; the rest fall back to who shared it, which is the
  # one fact about them that has not changed.
  defp detail(_subject, %{state: :ended} = card) do
    case card[:metrics] do
      %{duration_seconds: seconds, visitors: visitors}
      when is_integer(seconds) and is_integer(visitors) and visitors > 0 ->
        dngettext(
          "share",
          "lasted %{duration} · %{count} person took part",
          "lasted %{duration} · %{count} people took part",
          visitors,
          duration: humanize_duration(seconds),
          count: visitors
        )

      %{duration_seconds: seconds} when is_integer(seconds) ->
        dgettext("share", "lasted %{duration}", duration: humanize_duration(seconds))

      _none ->
        shared_by(card)
    end
  end

  defp detail(_subject, %{kind: kind, participants: [_ | _] = nicks, count: count})
       when kind in ["call", "space", "channel"] do
    dngettext(
      "share",
      "%{names} · %{count} person inside now",
      "%{names} · %{count} people inside now",
      count,
      names: Enum.join(nicks, ", "),
      count: count
    )
  end

  defp detail(_subject, %{kind: kind, count: count})
       when kind in ["call", "space", "channel"] and is_integer(count) do
    dngettext(
      "share",
      "%{count} person inside now",
      "%{count} people inside now",
      count,
      count: count
    )
  end

  defp detail(%{tagline: tagline}, %{kind: "play"}) when is_binary(tagline), do: tagline
  defp detail(_subject, %{kind: "play"}), do: dgettext("share", "One seat open")
  defp detail(_subject, card), do: shared_by(card)

  defp metric(card, key) do
    case card[:metrics] do
      %{^key => value} when is_integer(value) -> to_string(value)
      _absent -> nil
    end
  end

  # Rounded to the unit a person would use out loud. A conference that ran for
  # forty seconds "lasted less than a minute" — the exact number is a fact about
  # the clock, not about the meeting.
  defp humanize_duration(seconds) when seconds < 60,
    do: dgettext("share", "less than a minute")

  defp humanize_duration(seconds) when seconds < 3600 do
    minutes = div(seconds, 60)

    dngettext("share", "%{count} minute", "%{count} minutes", minutes, count: minutes)
  end

  defp humanize_duration(seconds) do
    hours = div(seconds, 3600)

    dngettext("share", "%{count} hour", "%{count} hours", hours, count: hours)
  end

  defp shared_by(%{creator_nick: nick}) when is_binary(nick),
    do: dgettext("share", "shared by %{nickname}", nickname: nick)

  defp shared_by(_card), do: dgettext("share", "shared with this conversation")

  # Whether the detail line is the one that names who shared the link — the
  # only place the card writes a person's nickname on its own.
  defp names_creator?(subject, %{creator_nick: nick} = card) when is_binary(nick),
    do: detail(subject, card) == shared_by(card)

  defp names_creator?(_subject, _card), do: false

  # Only a match has anywhere to send the reader. Everything else falls through
  # to `nil` and draws no button at all — the catch-all here used to say "Back
  # to the chat" to somebody who was reading it *in* the chat.
  defp next_label(%{name: name}, %{kind: "play"}) when is_binary(name),
    do: dgettext("share", "Play %{game}", game: name)

  defp next_label(_subject, %{kind: "play"}), do: dgettext("share", "Play")
  defp next_label(_subject, _card), do: nil
end

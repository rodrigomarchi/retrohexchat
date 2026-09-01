defmodule RetroHexChatWeb.Components.UI.ShareMessageCard do
  @moduledoc """
  A shared link, drawn in the conversation as the room it names.

  Three kinds — a conference, a space, a game — and two states each. Live, it
  says who is in there and offers the way in beside the way to pass it on.
  Ended, it says what happened and offers **the next plausible thing**, never a
  dead end: a call that finished offers the channel it happened in, a match
  somebody already took offers the game itself.

  The card never names a channel the reader could not have found on their own.
  That decision is made in the domain (`ShareLinks.Card`, via
  `Channels.Visibility.nameable?/1`) and arrives here as a `channel_name` that
  is either there or `nil` — because a component that decided it would be a
  second copy of the rule, and the two would drift.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :card, :map,
    default: nil,
    doc: "a `ShareLinks.Card`, or nil when the message carries no link of ours"

  attr :subject, :map, default: nil, doc: "%{name, tagline, icon} for what was shared"
  attr :enter_path, :string, default: nil
  attr :share_url, :string, default: nil, doc: "the address to hand on, for the Copy button"
  attr :next_path, :string, default: nil, doc: "where an ended card points instead of in"

  @spec share_message_card(map()) :: Phoenix.LiveView.Rendered.t()
  def share_message_card(assigns) do
    assigns = assign(assigns, :ended?, ended?(assigns.card))

    ~H"""
    <div
      :if={@card}
      class={[
        "shadow-retro-field bg-canvas my-1 flex max-w-md items-center gap-2 p-2",
        @ended? && "opacity-70"
      ]}
      data-testid="share-message-card"
      data-share-kind={@card.kind}
      data-share-state={state(@card)}
      data-share-count={@card[:count]}
      data-share-duration={metric(@card, :duration_seconds)}
      data-share-visitors={metric(@card, :visitors)}
    >
      <span class="shrink-0">
        {apply(Icons, icon_name(@subject, @card), [%{class: "h-8 w-8"}])}
      </span>

      <span class="min-w-0 flex-1">
        <span class="flex min-w-0 items-center gap-1">
          <span class="min-w-0 flex-1 truncate font-bold">{heading(@subject, @card)}</span>
          <span
            class={["shrink-0 text-[10px] font-bold uppercase", not @ended? && "text-primary"]}
            data-testid="share-message-state"
          >
            {badge(@card)}
          </span>
        </span>
        <span class="text-muted-foreground block truncate text-sm" data-testid="share-message-detail">
          {detail(@subject, @card)}
        </span>
      </span>

      <%!-- A card that has ended keeps a way forward and loses the way in: the
            room is not there to be entered, and a button that says Join and
            cannot is worse than no button. --%>
      <.button
        :if={not @ended? and @enter_path}
        navigate={@enter_path}
        size="sm"
        class="shrink-0"
        data-testid="share-message-enter"
      >
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {dgettext("share", "Join")}
      </.button>

      <.button
        :if={not @ended? and @share_url}
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

      <.button
        :if={@ended? and @next_path}
        navigate={@next_path}
        size="sm"
        variant="outline"
        class="shrink-0"
        data-testid="share-message-next"
      >
        <:icon><Icons.icon_btn_link class="h-4 w-4" /></:icon>
        {next_label(@subject, @card)}
      </.button>
    </div>
    """
  end

  @doc "Whether this card describes something that is no longer running."
  @spec ended?(map() | nil) :: boolean()
  def ended?(%{state: :ended}), do: true
  def ended?(_card), do: false

  defp state(%{state: :ended}), do: "ended"
  defp state(_card), do: "live"

  defp icon_name(%{icon: icon}, _card) when is_binary(icon) do
    name = :"icon_#{icon}"
    if function_exported?(Icons, name, 1), do: name, else: :icon_hex_stone
  end

  defp icon_name(_subject, %{kind: "play"}), do: :icon_game_pong
  defp icon_name(_subject, %{kind: "call"}), do: :icon_protocol_conference_compact
  defp icon_name(_subject, %{kind: "space"}), do: :icon_community
  defp icon_name(_subject, _card), do: :icon_hex_stone

  # The heading names the channel only when the domain said it may be named;
  # otherwise it says what kind of room it is and nothing about which one.
  defp heading(subject, %{kind: "play"} = card), do: game_heading(subject, card)

  defp heading(_subject, %{kind: "call", channel_name: channel}) when is_binary(channel),
    do: dgettext("share", "Call in %{channel}", channel: channel)

  defp heading(_subject, %{kind: "space", channel_name: channel}) when is_binary(channel),
    do: dgettext("share", "Space of %{channel}", channel: channel)

  defp heading(%{name: name}, _card) when is_binary(name), do: name
  defp heading(_subject, %{kind: "call"}), do: dgettext("share", "A conference")
  defp heading(_subject, %{kind: "space"}), do: dgettext("share", "A virtual space")
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
       when kind in ["call", "space"] do
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
       when kind in ["call", "space"] and is_integer(count) do
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

  defp next_label(_subject, %{kind: "call", channel_name: channel}) when is_binary(channel),
    do: dgettext("share", "Open %{channel}", channel: channel)

  defp next_label(%{name: name}, %{kind: "play"}) when is_binary(name),
    do: dgettext("share", "Play %{game}", game: name)

  defp next_label(_subject, %{kind: "play"}), do: dgettext("share", "Play")
  defp next_label(_subject, _card), do: dgettext("share", "Back to the chat")
end

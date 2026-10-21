defmodule RetroHexChatWeb.Components.UI.MessageReactions do
  @moduledoc """
  The reactions under a message, and the quick picks that add one.

  Composed from the button primitive rather than drawn: a chip is a small
  two-state button, which is what the design system already has, and a
  look-alike built out of raw markup would drift from its focus, disabled and
  sizing rules. Chips and picks use its frameless `link` variant and draw the
  emoji alone — a row of framed squares under every line is louder than the
  conversation.

  The picker is a smiley at the right end of the line's head, drawn on every
  stored message and on every screen, so reaching it needs no hover a touch
  screen does not have.

  The strip renders only when there is something in it. A blank row under every
  line is fifty blank rows in a page of history, and the row this sits in
  distinguishes "no reactions" from "no reactions yet" by simply not being
  there.

  Whether a chip is the reader's own is decided here, from the list of people
  in it, so the server stores one summary for a message instead of one per
  reader.

  ## Usage

      <.message_reactions
        message_id={42}
        reactions={%{"👍" => %{count: 2, actors: ["Ana", "Bo"]}}}
        viewer="Ana"
        on_toggle="toggle_reaction"
      />

      <.message_reaction_picker message_id={42} author="Bo" on_toggle="toggle_reaction" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.Popover

  alias RetroHexChat.Chat.EmojiData
  alias RetroHexChatWeb.Icons

  # The five a person reaches for without thinking. Deliberately fixed rather
  # than "most used on this server": a ranking would be a query on the render
  # path of every line, and a bar whose contents move is a bar you have to read
  # before you can click it.
  @quick_picks [
    "\u{1F44D}",
    "\u{2764}\u{FE0F}",
    "\u{1F602}",
    "\u{1F525}",
    "\u{1F440}"
  ]

  @doc "Renders the reactions a message already carries."
  attr :message_id, :any, required: true

  attr :reactions, :map,
    default: nil,
    doc: "emoji => %{count:, actors: []}; nil when there are none"

  attr :viewer, :string, default: nil, doc: "whose chips are drawn as pressed"

  attr :source, :atom,
    default: nil,
    doc: "`:channel` or `:private` — the two are numbered apart, so the id alone is ambiguous"

  attr :on_toggle, :any, default: nil
  attr :class, :any, default: nil

  @spec message_reactions(map()) :: Phoenix.LiveView.Rendered.t()
  def message_reactions(assigns) do
    assigns = assign(assigns, :entries, entries(assigns.reactions))

    ~H"""
    <div
      :if={@entries != []}
      class={classes(["message-reactions", @class])}
      data-testid={"message-reactions-#{@message_id}"}
    >
      <.button
        :for={{emoji, count, actors} <- @entries}
        variant="link"
        size="sm"
        class={classes(["message-reaction", mine?(actors, @viewer) && "message-reaction--mine"])}
        aria-pressed={to_string(mine?(actors, @viewer))}
        title={actors_title(actors)}
        phx-click={@on_toggle}
        phx-value-message_id={@message_id}
        phx-value-source={@source}
        phx-value-emoji={emoji}
        data-testid={"message-reaction-#{@message_id}-#{emoji}"}
      >
        <:icon>{emoji}</:icon>
        {count}
      </.button>
    </div>
    """
  end

  @doc "Renders the smiley that opens the handful of emoji offered for a message."
  attr :message_id, :any, required: true

  attr :source, :atom,
    default: nil,
    doc: "`:channel` or `:private` — the two are numbered apart, so the id alone is ambiguous"

  attr :author, :string,
    default: nil,
    doc: "who wrote the line, so each row's trigger has a name of its own"

  attr :on_toggle, :any, default: nil
  attr :class, :any, default: nil

  @spec message_reaction_picker(map()) :: Phoenix.LiveView.Rendered.t()
  def message_reaction_picker(assigns) do
    assigns = assign(assigns, :quick_picks, quick_picks())

    ~H"""
    <.popover
      label={picker_label(@author)}
      placement="above-end"
      class={classes(["message-react", @class])}
      trigger_class="message-react-trigger"
      trigger_testid={"message-react-trigger-#{@message_id}"}
      panel_class="message-reaction-bar"
      panel_testid={"message-reaction-bar-#{@message_id}"}
    >
      <:trigger><Icons.icon_fmt_emoji class="h-3.5 w-3.5" /></:trigger>
      <.button
        :for={emoji <- @quick_picks}
        variant="link"
        size="sm"
        class="message-reaction"
        title={dgettext("chat", "React with %{emoji}", emoji: emoji)}
        aria-label={dgettext("chat", "React with %{emoji}", emoji: emoji)}
        phx-click={@on_toggle && close_after(@on_toggle)}
        phx-value-message_id={@message_id}
        phx-value-source={@source}
        phx-value-emoji={emoji}
        data-testid={"message-reaction-pick-#{@message_id}-#{emoji}"}
      >
        <:icon>{emoji}</:icon>
      </.button>
    </.popover>
    """
  end

  @doc """
  The emoji offered without opening the picker.

  Filtered against the catalog because a pick outside it would be a button that
  answers with an error. The filter is a net, not the rule — a pick that falls
  through it is a mistake in the list above, and `message_reactions_test.exs`
  fails on a shorter bar rather than letting one quietly disappear.
  """
  @spec quick_picks() :: [String.t()]
  def quick_picks, do: Enum.filter(@quick_picks, &EmojiData.known?/1)

  @spec picker_label(String.t() | nil) :: String.t()
  defp picker_label(nil), do: dgettext("chat", "React")
  defp picker_label(author), do: dgettext("chat", "React to %{nick}", nick: author)

  @spec entries(map() | nil) :: [{String.t(), non_neg_integer(), [String.t()]}]
  defp entries(reactions) when is_map(reactions) do
    reactions
    |> Enum.map(fn {emoji, %{count: count} = entry} ->
      {emoji, count, Map.get(entry, :actors, [])}
    end)
    |> Enum.reject(fn {_emoji, count, _actors} -> count == 0 end)
    |> Enum.sort_by(fn {emoji, count, _actors} -> {-count, emoji} end)
  end

  defp entries(_reactions), do: []

  @spec mine?([String.t()], String.t() | nil) :: boolean()
  defp mine?(_actors, nil), do: false

  defp mine?(actors, viewer) do
    downcased = String.downcase(viewer)
    Enum.any?(actors, &(String.downcase(&1) == downcased))
  end

  @spec actors_title([String.t()]) :: String.t()
  defp actors_title(actors), do: Enum.join(actors, ", ")
end

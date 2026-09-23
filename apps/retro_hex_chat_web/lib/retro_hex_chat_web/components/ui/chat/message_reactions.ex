defmodule RetroHexChatWeb.Components.UI.MessageReactions do
  @moduledoc """
  The reactions under a message, and the quick picks that add one.

  Two components, composed from the button primitive rather than drawn: a chip
  is a small two-state button, which is what the design system already has, and
  a second look-alike built out of raw markup would drift from it the first
  time the retro bevel changes.

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

      <.message_reaction_bar message_id={42} on_toggle="toggle_reaction" />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChat.Chat.EmojiData

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
        variant="outline"
        size="sm"
        class={classes(["message-reaction", mine?(actors, @viewer) && "message-reaction--mine"])}
        aria-pressed={to_string(mine?(actors, @viewer))}
        title={actors_title(actors)}
        phx-click={@on_toggle}
        phx-value-message_id={@message_id}
        phx-value-emoji={emoji}
        data-testid={"message-reaction-#{@message_id}-#{emoji}"}
      >
        <:icon>{emoji}</:icon>
        {count}
      </.button>
    </div>
    """
  end

  @doc "Renders the handful of emoji offered without opening anything."
  attr :message_id, :any, required: true
  attr :on_toggle, :any, default: nil
  attr :class, :any, default: nil

  @spec message_reaction_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def message_reaction_bar(assigns) do
    assigns = assign(assigns, :quick_picks, quick_picks())

    ~H"""
    <div
      class={classes(["message-reaction-bar", @class])}
      data-testid={"message-reaction-bar-#{@message_id}"}
    >
      <.button
        :for={emoji <- @quick_picks}
        variant="outline"
        size="sm"
        class="message-reaction"
        title={dgettext("chat", "React with %{emoji}", emoji: emoji)}
        phx-click={@on_toggle}
        phx-value-message_id={@message_id}
        phx-value-emoji={emoji}
        data-testid={"message-reaction-pick-#{@message_id}-#{emoji}"}
      >
        <:icon>{emoji}</:icon>
        <span class="sr-only">{dgettext("chat", "React")}</span>
      </.button>
    </div>
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

defmodule RetroHexChatWeb.Components.UI.ChatCard do
  @moduledoc """
  The one shape a card takes inside the conversation: an event, a shared room,
  a help topic, the greeting a visitor gets.

  **No frame.** A card hangs under the line that announced it, on the
  conversation's own white, and the row's spine already sets it apart from the
  lines around it. A sunken bevel around it drew a field nobody can type into,
  and made the one thing in the conversation meant to be read the one thing
  boxed off from it. What separates a card is its spacing, its bold title and
  its upright text — `.chat-card` takes back the body text a system line's grey
  italic would otherwise hand it.

  Two layouts:

    * `:row` — a picture of the thing on the left, the words beside it. For a
      card about one object: an event, a room.
    * `:block` — a title and then text. For a card that is mostly reading: a
      help topic, a greeting.

  Either way the actions sit under the words, in one row, so a card that grows
  a third button grows downward instead of squeezing its title.

  A link preview is not one of these: it quotes another page and is drawn as a
  quotation (`.chat-link-card`, a bar on its left), so it never reads as
  something this app is offering.

  ## Usage

      <.chat_card layout={:row} data-testid="event-card-7">
        <:icon><Icons.icon_clock class="h-8 w-8" /></:icon>
        <:title>Movie night</:title>
        <:badge><.chat_card_badge tone={:muted}>Called off</.chat_card_badge></:badge>
        <span class="block text-muted-foreground">Fri 20:00</span>
        <:actions><.button size="sm">I'm going</.button></:actions>
      </.chat_card>
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  attr :layout, :atom, values: [:row, :block], default: :block
  attr :class, :any, default: nil
  attr :rest, :global

  slot :icon, doc: "`:row` only — a 32×32 picture of the thing"
  slot :title, doc: "the card's name, bold; truncated in `:row`"
  slot :badge, doc: "one word of state beside the title — a `chat_card_badge/1`"
  slot :inner_block
  slot :actions, doc: "the controls, in one row under the words"

  @doc "Renders a card inside a conversation row."
  @spec chat_card(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_card(%{layout: :row} = assigns) do
    ~H"""
    <div
      class={classes(["chat-card my-1 flex max-w-xl items-start gap-2 py-1 text-sm", @class])}
      {@rest}
    >
      <span :if={@icon != []} class="shrink-0">{render_slot(@icon)}</span>
      <div class="min-w-0 flex-1">
        <div :if={@title != [] or @badge != []} class="flex min-w-0 items-center gap-1">
          <span class="min-w-0 flex-1 truncate font-bold">{render_slot(@title)}</span>
          {render_slot(@badge)}
        </div>
        {render_slot(@inner_block)}
        <.card_actions actions={@actions} />
      </div>
    </div>
    """
  end

  def chat_card(assigns) do
    ~H"""
    <div class={classes(["chat-card my-1 max-w-xl space-y-2 py-1 text-sm", @class])} {@rest}>
      <div :if={@title != [] or @badge != []} class="flex min-w-0 items-center gap-1">
        <h3 class="min-w-0 flex-1 font-bold">{render_slot(@title)}</h3>
        {render_slot(@badge)}
      </div>
      {render_slot(@inner_block)}
      <.card_actions actions={@actions} />
    </div>
    """
  end

  attr :actions, :list, required: true

  defp card_actions(assigns) do
    ~H"""
    <div :if={@actions != []} class="mt-1 flex flex-wrap items-center gap-2">
      {render_slot(@actions)}
    </div>
    """
  end

  attr :tone, :atom,
    values: [:live, :muted],
    default: :muted,
    doc: "`:live` for something happening now, `:muted` for a record or a refusal"

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @doc """
  The one word that says whether the thing on a card is happening.

  State is said here, in the word and its colour — never by dimming the card.
  Seven tenths opacity is how this product draws a control it has refused, and
  a card that has ended is a record somebody may read weeks later, not a broken
  button.
  """
  @spec chat_card_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def chat_card_badge(assigns) do
    ~H"""
    <span
      class={[
        "shrink-0 text-[10px] font-bold uppercase",
        if(@tone == :live, do: "text-primary", else: "text-muted-foreground"),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  attr :href, :string, required: true
  attr :label, :string, required: true, doc: "what is being opened, for the tab confirmation"
  attr :as, :atom, values: [:link, :button], default: :link
  attr :class, :any, default: nil
  attr :rest, :global
  slot :icon, doc: "`:button` only"
  slot :inner_block, required: true

  @doc """
  The way from a card to the place it names, opened in a tab of its own.

  A real anchor with `href`, never `navigate`: following it in the same tab
  would take the conversation away, and the card is sitting in that
  conversation. `rel="noopener"` because without it the new tab shares this
  one's event loop, and a room renegotiating media would be doing it inside the
  chat's.
  """
  @spec surface_link(map()) :: Phoenix.LiveView.Rendered.t()
  def surface_link(%{as: :button} = assigns) do
    ~H"""
    <.button
      href={@href}
      target="_blank"
      rel="noopener"
      data-confirm-tab="surface"
      data-confirm-label={@label}
      size="sm"
      class={["shrink-0", @class]}
      {@rest}
    >
      <:icon :for={icon <- @icon}>{render_slot(icon)}</:icon>
      {render_slot(@inner_block)}
    </.button>
    """
  end

  def surface_link(assigns) do
    ~H"""
    <.link
      href={@href}
      target="_blank"
      rel="noopener"
      data-confirm-tab="surface"
      data-confirm-label={@label}
      class={["underline", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end
end

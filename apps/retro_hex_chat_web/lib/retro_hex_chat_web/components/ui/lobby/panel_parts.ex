defmodule RetroHexChatWeb.Components.UI.Lobby.PanelParts do
  @moduledoc """
  The pieces an activity panel of the P2P session console is built from — the
  Games panel and the Files panel draw the same states the same way.

    * `disconnected_section/1` — the whole panel while the P2P connection is not
      up yet: its header saying Offline, and one line on what connecting allows.
    * `state_card/1` — one moment of an activity that waits on somebody: an
      invitation to answer, an answer being waited for, a score to read. A
      picture, the words, and the answers under them, on a card raised
      straight off the panel — never boxed again in a field of its own.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Badge
  import RetroHexChatWeb.Components.UI.IconWell
  import RetroHexChatWeb.Components.UI.MediaSession.StatusHeader

  alias RetroHexChatWeb.Icons

  attr :title, :string, required: true
  attr :icon, :atom, required: true, doc: "the activity's icon function"
  attr :text, :string, required: true, doc: "what connecting would let the reader do"
  attr :testid, :string, required: true
  attr :header_testid, :string, required: true

  @doc "An activity panel before the P2P connection is up."
  @spec disconnected_section(map()) :: Phoenix.LiveView.Rendered.t()
  def disconnected_section(assigns) do
    ~H"""
    <section class="flex h-full min-h-[180px] flex-col gap-2 bg-surface p-2" data-testid={@testid}>
      <.media_session_status_header
        title={@title}
        testid={@header_testid}
        class="p-2 shadow-retro-field"
      >
        <:icon>{apply(Icons, @icon, [%{class: "h-5 w-5 shrink-0"}])}</:icon>
        <:meta>
          <span>{dgettext("lobby", "Waiting for P2P connection")}</span>
        </:meta>
        <:facets>
          <.badge variant="muted" size="xs" bevel="sunken">{dgettext("chat", "Offline")}</.badge>
        </:facets>
      </.media_session_status_header>

      <div class="shadow-retro-field flex min-h-0 flex-1 items-center justify-center bg-white p-4 text-center text-xs text-muted-foreground">
        <div class="max-w-[18rem] space-y-2">
          {apply(Icons, @icon, [%{class: "mx-auto h-6 w-6"}])}
          <p>{@text}</p>
        </div>
      </div>
    </section>
    """
  end

  attr :class, :any, default: nil, doc: "how the card's field fills its parent"
  attr :rest, :global
  slot :icon, required: true, doc: "drawn in a 40 px well"
  slot :inner_block, required: true, doc: "the words beside the picture"
  slot :detail, doc: "a block under the words, before the answers"
  slot :actions, doc: "the answers, right-aligned under the card"

  @doc "One moment of an activity, a raised card centred on the panel."
  @spec state_card(map()) :: Phoenix.LiveView.Rendered.t()
  def state_card(assigns) do
    ~H"""
    <div
      class={
        classes([
          "flex min-h-[220px] items-center justify-center p-3 text-xs sm:min-h-[300px]",
          @class
        ])
      }
      {@rest}
    >
      <div class="w-full max-w-[30rem] border border-border bg-surface p-2 text-left shadow-retro-raised">
        <div class="flex min-w-0 items-start gap-2">
          <.icon_well size="md">{render_slot(@icon)}</.icon_well>
          <div class="min-w-0 flex-1">{render_slot(@inner_block)}</div>
        </div>
        {render_slot(@detail)}
        <div :if={@actions != []} class="mt-3 flex justify-end gap-1">{render_slot(@actions)}</div>
      </div>
    </div>
    """
  end
end

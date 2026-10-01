defmodule RetroHexChatWeb.Components.UI.EventsDialog do
  @moduledoc """
  What the channel on screen has coming up, soonest first.

  Every row is the same `event_card` the conversation draws, because an event is
  one thing and a window that drew a second version of it would be a second
  place to keep the design right. The window adds only what a list adds: order,
  paging, and the sentence for when there is nothing in it.

  No row formats a time. The instants are UTC and whose clock to use is the
  session's business, so the formatted strings arrive with the rows.
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.EventCard
  import RetroHexChatWeb.Components.UI.ListStates
  import RetroHexChatWeb.Components.UI.DialogBanner

  alias RetroHexChatWeb.Components.Diagrams
  alias RetroHexChatWeb.Icons
  alias RetroHexChatWeb.PaginatedList.State

  @doc "Renders the Events window body."
  attr :id, :string, required: true
  attr :first_row, :map, default: nil, doc: "Soonest event, for the banner picture"
  attr :events, :any, required: true, doc: "the stream of event rows"
  attr :state, :any, default: nil, doc: "PaginatedList.State for the list"
  attr :target, :any, default: nil
  attr :can_schedule, :boolean, default: false

  @spec events_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def events_panel(assigns) do
    ~H"""
    <div id={"#{@id}-panel"} class="flex h-full min-h-0 flex-col gap-retro-4">
      <.dialog_banner heading={dgettext("dialogs", "What the room has coming up")}>
        <:art>
          <Diagrams.diagram_dialog_preview
            kind={:schedule}
            title={dgettext("dialogs", "Channel")}
            lines={event_lines(@first_row)}
            label={dgettext("dialogs", "A miniature of the next event and when it starts")}
          />
        </:art>
        <:glyph><Icons.icon_clock class="h-8 w-8" /></:glyph>
        {dgettext(
          "dialogs",
          "An event belongs to the channel, so everybody in it sees the same list and is told in the room when the time comes. Only an operator can put one on the calendar."
        )}
      </.dialog_banner>

      <.list_empty_state
        :if={State.empty?(@state)}
        icon={:clock}
        title={dgettext("dialogs", "Nothing is planned yet.")}
        text={
          if @can_schedule,
            do:
              dgettext(
                "dialogs",
                "Use /event 2h Tuesday tournament to put something on the calendar. Everyone in the channel sees it and can say they are going."
              ),
            else:
              dgettext(
                "dialogs",
                "When an operator schedules something, it shows up here and in the conversation."
              )
        }
      />

      <div
        :if={not State.empty?(@state)}
        id={"#{@id}-list"}
        class="min-h-[200px] flex-1 overflow-y-auto bg-white p-1 shadow-retro-field retro-scrollbar"
        phx-hook="InfiniteScrollHook"
        phx-update="stream"
        data-edge="bottom"
        data-target={@target}
        data-event="events_load_more"
        data-has-more={to_string(State.more?(@state))}
        data-loading={to_string(State.loading?(@state))}
        data-testid="events-list"
      >
        <div
          :for={{dom_id, row} <- @events}
          id={dom_id}
          data-testid={"events-row-#{row.card.event_id}"}
        >
          <.event_card
            card={row.card}
            when_text={row.when_text}
            relative_text={row.relative_text}
            attending={row.attending}
            on_attend="event_attend"
            on_unattend="event_unattend"
            class="max-w-none"
          />
        </div>
      </div>

      <.list_load_more_button
        :if={State.more?(@state)}
        target={@target}
        event="events_load_more"
        loading={State.loading?(@state)}
        testid="events-load-more"
      />
      <.list_announcer state={@state} />
      <.list_error_retry
        :if={State.error?(@state)}
        target={@target}
        on_retry="events_load_more"
        text={dgettext("dialogs", "Could not load more events.")}
      />
      <.list_end_marker :if={State.exhausted?(@state)} testid="events-end" />
    </div>
    """
  end

  # The soonest one, which is the only part of the list that is news.
  @spec event_lines(map() | nil) :: [map()]
  defp event_lines(nil), do: []

  defp event_lines(row) do
    # The row wraps the card the list renders; the title lives on the card.
    card = Map.get(row, :card) || %{}

    [
      %{text: Map.get(card, :title) || "", tone: :accent},
      %{text: Map.get(row, :when_text) || "", tone: :muted}
    ]
  end
end

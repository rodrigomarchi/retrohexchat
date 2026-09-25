defmodule RetroHexChatWeb.Components.UI.EventCard do
  @moduledoc """
  Something the channel is going to do, drawn under the line that announced it.

  The card carries the one interaction an event has — saying you will be there —
  because that is where the reader already is. A list they have to open first is
  a list most of them never open, and an answer nobody gives is a reminder
  nobody gets.

  It never formats the time itself. The instant is UTC and the reader's zone
  belongs to the session, so the formatted string arrives as an assign: a
  component that reached for a clock would be a second place that decides whose
  clock, and the two would disagree.

  ## Usage

      <.event_card
        card={%{event_id: 7, title: "Tuesday tournament", …}}
        when_text="25/09 20:00"
        relative_text="in 2 hours"
        attending={false}
        on_attend="event_attend"
        on_unattend="event_unattend"
      />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Button

  alias RetroHexChatWeb.Icons

  attr :card, :map, default: nil, doc: "a `ScheduledEvents.card`, or nil for a plain line"
  attr :when_text, :string, default: nil, doc: "the start, in the reader's own zone"
  attr :relative_text, :string, default: nil, doc: "how far off it is, in words"
  attr :attending, :boolean, default: false
  attr :on_attend, :any, default: nil
  attr :on_unattend, :any, default: nil

  attr :surface_path, :string,
    default: nil,
    doc: "where the event happens, when it has an address"

  attr :class, :any, default: nil

  @spec event_card(map()) :: Phoenix.LiveView.Rendered.t()
  def event_card(assigns) do
    ~H"""
    <div
      :if={@card}
      class={[
        "chat-event-card shadow-retro-field bg-canvas my-1 flex max-w-md items-start gap-2 p-2",
        @card.cancelled? && "opacity-70",
        @class
      ]}
      data-testid={"event-card-#{@card.event_id}"}
      data-event-state={if @card.cancelled?, do: "cancelled", else: "scheduled"}
      data-event-attendees={@card.attendee_count}
    >
      <span class="shrink-0">
        <Icons.icon_clock class="h-8 w-8" />
      </span>

      <span class="min-w-0 flex-1">
        <span class="flex min-w-0 items-center gap-1">
          <span class="min-w-0 flex-1 truncate font-bold">{@card.title}</span>
          <span
            :if={@card.cancelled?}
            class="shrink-0 text-[10px] font-bold uppercase"
            data-testid="event-card-cancelled"
          >
            {dgettext("chat", "Called off")}
          </span>
        </span>

        <%!-- Both readings of the same instant. The clock time is what somebody
              writes down; "in two hours" is what tells them whether to stop
              what they are doing, and neither answers for the other. --%>
        <span class="block text-muted-foreground">
          <span data-testid={"event-when-#{@card.event_id}"}>{@when_text}</span>
          <span :if={@relative_text}>· {@relative_text}</span>
        </span>

        <span :if={@card.description} class="mt-1 block break-words">{@card.description}</span>

        <span class="mt-1 flex items-center gap-2">
          <.button
            :if={not @card.cancelled?}
            type="button"
            size="sm"
            variant={if @attending, do: "default", else: "outline"}
            phx-click={if @attending, do: @on_unattend, else: @on_attend}
            phx-value-event_id={@card.event_id}
            aria-pressed={to_string(@attending)}
            data-testid={"event-attend-#{@card.event_id}"}
          >
            <:icon><Icons.icon_checkmark class="h-4 w-4" /></:icon>
            {if @attending, do: dgettext("chat", "Going"), else: dgettext("chat", "I'm going")}
          </.button>

          <span class="text-muted-foreground" data-testid={"event-count-#{@card.event_id}"}>
            {dngettext(
              "chat",
              "%{count} going",
              "%{count} going",
              @card.attendee_count,
              count: @card.attendee_count
            )}
          </span>

          <.link
            :if={@surface_path && not @card.cancelled?}
            navigate={@surface_path}
            target="_blank"
            class="ml-auto underline"
            data-testid={"event-surface-#{@card.event_id}"}
          >
            {dgettext("chat", "Where")}
          </.link>
        </span>
      </span>
    </div>
    """
  end
end

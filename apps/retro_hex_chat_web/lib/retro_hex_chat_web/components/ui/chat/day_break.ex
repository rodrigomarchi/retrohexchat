defmodule RetroHexChatWeb.Components.UI.DayBreak do
  @moduledoc """
  The perforation between two days of a conversation, with the date it opens.

  Drawn *inside* the first row of the day, above the row's own band, for the
  same reasons as `UnreadDivider`: a stream container needs an id on every
  child, and a synthetic row would reorder and be pruned by the stream's
  negative `limit:`.

  ## Usage

      <.day_break :if={@msg[:day_break]} date={@msg.day_break} />
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.App.ChatHelpers

  @doc "Renders the day perforation."
  attr :date, Date, required: true
  attr :class, :any, default: nil

  @spec day_break(map()) :: Phoenix.LiveView.Rendered.t()
  def day_break(assigns) do
    assigns = assign(assigns, :label, ChatHelpers.format_day(assigns.date))

    ~H"""
    <div
      class={classes(["day-break", @class])}
      role="separator"
      aria-label={@label}
      data-testid="day-break"
    >
      <span class="day-break__label">{@label}</span>
    </div>
    """
  end
end

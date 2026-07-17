defmodule RetroHexChatWeb.Components.UI.MediaSession.SummaryCard do
  @moduledoc """
  Compact summary cards for media-session stats panels.

  These cards are the summary-first layer above detailed diagnostics. They do
  not compute metrics; callers pass measured labels and values.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :icon, :atom, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :detail, :string, required: true
  attr :tone_class, :any, default: nil
  attr :class, :any, default: nil
  attr :testid, :string, required: true

  @spec summary_card(map()) :: Phoenix.LiveView.Rendered.t()
  def summary_card(assigns) do
    ~H"""
    <div
      class={
        classes([
          "min-w-0 border border-border px-2 py-1 shadow-retro-sunken",
          @class
        ])
      }
      data-testid={@testid}
    >
      <div class="flex min-w-0 items-center gap-1 text-[10px] font-bold uppercase text-muted-foreground">
        {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
        <span class="truncate">{@label}</span>
      </div>
      <div class={classes(["truncate text-sm font-bold leading-5", @tone_class])}>
        {@value}
      </div>
      <div class="truncate text-[10px] leading-3 text-muted-foreground">
        {@detail}
      </div>
    </div>
    """
  end
end

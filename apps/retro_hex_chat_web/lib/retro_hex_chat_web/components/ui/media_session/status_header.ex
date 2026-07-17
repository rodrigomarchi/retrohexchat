defmodule RetroHexChatWeb.Components.UI.MediaSession.StatusHeader do
  @moduledoc """
  Shared status header for media-session inspectors and stats panels.

  The component owns only the layout for identity, status metadata, and optional
  right-aligned facets. Metrics, summaries, tabs, and hooks stay in callers.
  """
  use RetroHexChatWeb.Component

  attr :title, :string, required: true
  attr :class, :any, default: "shadow-retro-field bg-canvas p-2"
  attr :title_class, :any, default: "truncate font-bold leading-4"

  attr :meta_class, :any,
    default:
      "flex min-w-0 flex-wrap items-center gap-x-2 gap-y-0.5 text-[10px] leading-3 text-muted-foreground"

  attr :facets_class, :any, default: "flex shrink-0 flex-wrap items-center justify-end gap-1"
  attr :testid, :string, default: nil

  slot :icon, required: true
  slot :meta
  slot :facets

  @spec media_session_status_header(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_status_header(assigns) do
    ~H"""
    <div class={classes([@class])} data-testid={@testid}>
      <div class="flex min-w-0 flex-wrap items-center justify-between gap-2">
        <div class="flex min-w-0 items-center gap-2">
          {render_slot(@icon)}
          <div class="min-w-0">
            <div class={classes([@title_class])}>{@title}</div>
            <div :if={@meta != []} class={classes([@meta_class])}>
              {render_slot(@meta)}
            </div>
          </div>
        </div>

        <div :if={@facets != []} class={classes([@facets_class])}>
          {render_slot(@facets)}
        </div>
      </div>
    </div>
    """
  end
end

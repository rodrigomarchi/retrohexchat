defmodule RetroHexChatWeb.Components.UI.MediaSession.Header do
  @moduledoc """
  Shared header shell for media-session surfaces.

  The component owns only the layout: icon, title, metadata row and optional
  actions. Callers keep all labels, state, events and action buttons local.
  """
  use RetroHexChatWeb.Component

  attr :title, :string, required: true

  attr :class, :any,
    default:
      "flex min-h-8 shrink-0 flex-wrap items-center justify-between gap-1 border border-border bg-surface px-2 py-1 shadow-retro-sunken"

  attr :title_class, :any, default: "truncate font-bold leading-4"

  attr :meta_class, :any,
    default:
      "flex min-w-0 flex-wrap items-center gap-x-2 gap-y-0.5 text-[10px] leading-3 text-muted-foreground"

  attr :actions_class, :any, default: "flex shrink-0 flex-wrap items-center justify-end gap-1"
  attr :actions_label, :string, default: nil
  attr :testid, :string, default: nil

  slot :icon, required: true
  slot :meta
  slot :actions

  @spec media_session_header(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_header(assigns) do
    ~H"""
    <header class={classes([@class])} data-testid={@testid}>
      <div class="flex min-w-0 flex-1 items-center gap-2">
        {render_slot(@icon)}
        <div class="min-w-0">
          <div class={classes([@title_class])}>{@title}</div>
          <div :if={@meta != []} class={classes([@meta_class])}>
            {render_slot(@meta)}
          </div>
        </div>
      </div>

      <div
        :if={@actions != []}
        class={classes([@actions_class])}
        role={if @actions_label, do: "toolbar"}
        aria-label={@actions_label}
      >
        {render_slot(@actions)}
      </div>
    </header>
    """
  end
end

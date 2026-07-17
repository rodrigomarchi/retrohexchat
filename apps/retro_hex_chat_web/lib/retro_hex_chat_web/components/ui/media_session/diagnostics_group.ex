defmodule RetroHexChatWeb.Components.UI.MediaSession.DiagnosticsGroup do
  @moduledoc """
  Collapsible diagnostics group for media-session stats panels.

  The summary row keeps the high-signal status visible while raw metrics remain
  available on demand. Callers own the metric data and lifecycle.
  """
  use RetroHexChatWeb.Component

  alias RetroHexChatWeb.Icons

  attr :title, :string, required: true
  attr :summary, :string, default: nil
  attr :icon, :atom, required: true
  attr :open, :boolean, default: false
  attr :class, :any, default: nil
  attr :body_class, :any, default: "p-2"
  attr :testid, :string, default: nil
  attr :rest, :global

  slot :inner_block, required: true

  @spec media_session_diagnostics_group(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_diagnostics_group(assigns) do
    ~H"""
    <details
      class={
        classes([
          "group/diagnostics border border-border bg-surface shadow-retro-sunken",
          @class
        ])
      }
      open={@open}
      data-testid={@testid}
      {@rest}
    >
      <summary class={[
        "flex min-h-8 cursor-pointer list-none items-center justify-between gap-2 px-2 py-1",
        "[&::-webkit-details-marker]:hidden"
      ]}>
        <span class="inline-flex min-w-0 flex-1 items-center gap-1 font-bold">
          {apply(Icons, @icon, [%{class: "h-3.5 w-3.5 shrink-0"}])}
          <span class="truncate">{@title}</span>
        </span>

        <span class="inline-flex min-w-0 max-w-[45%] shrink-0 items-center justify-end gap-1 text-muted-foreground">
          <span :if={@summary} class="truncate text-[10px]">
            {@summary}
          </span>
          <Icons.icon_chevron_right class="h-3 w-3 group-open/diagnostics:hidden" />
          <Icons.icon_chevron_down class="hidden h-3 w-3 group-open/diagnostics:block" />
        </span>
      </summary>

      <div class={classes(["border-t border-border", @body_class])}>
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end
end

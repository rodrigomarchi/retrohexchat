defmodule RetroHexChatWeb.Components.UI.MediaSession.SectionNav do
  @moduledoc """
  Shared section navigation for media-session surfaces.

  It is intentionally presentational. Callers own the selected section and the
  event that handles section changes.
  """
  use RetroHexChatWeb.Component

  attr :aria_label, :string, required: true
  attr :event, :any, required: true
  attr :testid, :string, required: true
  attr :testid_prefix, :string, required: true

  attr :class, :any,
    default: "flex shrink-0 flex-wrap border border-border bg-muted shadow-retro-sunken"

  attr :scroller_class, :any, default: "flex min-w-0 flex-1 gap-1 overflow-x-auto px-1 py-1"

  attr :button_class, :any, default: nil

  # Full width below sm so the controls wrap under the sections instead of
  # squeezing the scroller until the active section scrolls out of sight.
  attr :actions_class, :any,
    default: "flex w-full shrink-0 flex-wrap items-center justify-end gap-1 px-1 py-1 sm:w-auto"

  attr :actions_label, :string, default: nil

  slot :item, required: true do
    attr :section, :string, required: true
    attr :label, :string, required: true
    attr :active, :boolean, required: true
  end

  slot :actions,
    doc:
      "Window-level controls pinned to the trailing edge. They sit outside the scroller so " <>
        "they stay reachable when the section buttons overflow."

  @spec section_nav(map()) :: Phoenix.LiveView.Rendered.t()
  def section_nav(assigns) do
    ~H"""
    <nav
      class={classes(["min-w-0 items-start", @class])}
      aria-label={@aria_label}
      data-testid={@testid}
    >
      <span
        class="media-session-section-nav__cue"
        data-scroll-cue-edge="start"
        aria-hidden="true"
      >
        &lt;
      </span>

      <div
        class={classes(["media-session-section-nav", @scroller_class])}
        data-scroll-cue="horizontal"
      >
        <button
          :for={item <- @item}
          type="button"
          class={
            classes([
              "media-session-section-nav__item inline-flex h-8 shrink-0 items-center justify-center gap-1 px-2 text-xs font-bold shadow-retro-raised focus:outline-none focus-visible:ring-1 focus-visible:ring-foreground",
              @button_class,
              item.active && "bg-primary text-primary-foreground",
              !item.active && "bg-surface text-foreground"
            ])
          }
          phx-click={@event}
          phx-value-section={item.section}
          aria-pressed={to_string(item.active)}
          data-testid={"#{@testid_prefix}-#{item.section}"}
        >
          <span class="inline-flex h-4 w-4 shrink-0 items-center justify-center">
            {render_slot(item)}
          </span>
          <span class="truncate">{item.label}</span>
        </button>
      </div>

      <span
        class="media-session-section-nav__cue"
        data-scroll-cue-edge="end"
        aria-hidden="true"
      >
        &gt;
      </span>

      <div
        :if={@actions != []}
        class={classes([@actions_class])}
        role={if @actions_label, do: "toolbar"}
        aria-label={@actions_label}
      >
        {render_slot(@actions)}
      </div>
    </nav>
    """
  end
end

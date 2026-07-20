defmodule RetroHexChatWeb.Components.UI.MediaSession.InspectorPanel do
  @moduledoc """
  Shared inspector shell for media-session side panels and section panels.

  The component owns panel chrome, header layout, and scrollable body structure.
  Callers keep panel contents, labels, events, permissions, and data semantics.
  """
  use RetroHexChatWeb.Component

  attr :title, :string, required: true
  attr :aria_label, :string, required: true
  attr :role, :string, default: "complementary"

  attr :class, :any,
    default: "flex min-h-0 flex-col border border-border bg-surface shadow-retro-sunken"

  attr :header_class, :any,
    default: "flex min-h-8 shrink-0 items-center justify-between border-b border-border px-2"

  attr :title_class, :any, default: "truncate font-bold"
  attr :body_class, :any, default: "min-h-0 flex-1 overflow-auto p-1"
  attr :body_id, :string, default: nil
  attr :body_hook, :string, default: nil
  attr :body_preserve_scroll_target, :string, default: nil
  attr :testid, :string, default: nil
  attr :body_testid, :string, default: nil
  attr :body_role, :string, default: nil
  attr :body_aria_label, :string, default: nil
  attr :rest, :global

  slot :icon, required: true
  slot :meta
  slot :inner_block, required: true

  @spec media_session_inspector_panel(map()) :: Phoenix.LiveView.Rendered.t()
  def media_session_inspector_panel(assigns) do
    ~H"""
    <div
      class={classes([@class])}
      role={@role}
      aria-label={@aria_label}
      data-testid={@testid}
      {@rest}
    >
      <header class={classes([@header_class])}>
        <span class="inline-flex min-w-0 items-center gap-1">
          {render_slot(@icon)}
          <span class={classes([@title_class])}>{@title}</span>
        </span>
        <div
          :if={@meta != []}
          class="inline-flex shrink-0 items-center gap-1 text-muted-foreground"
        >
          {render_slot(@meta)}
        </div>
      </header>

      <div
        id={@body_id}
        phx-hook={@body_hook}
        data-preserve-scroll-target={@body_preserve_scroll_target}
        class={classes([@body_class])}
        role={@body_role}
        aria-label={@body_aria_label}
        data-testid={@body_testid}
      >
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end

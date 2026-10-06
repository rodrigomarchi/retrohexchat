defmodule RetroHexChatWeb.Components.UI.Popover do
  @moduledoc """
  A panel that opens from a trigger and floats over what is below it: a menu,
  a summary card, a row of reactions, a device picker.

  It is a `<details data-popover>` element, so it opens and closes without a
  round trip and keeps working with scripting off. Three behaviours come with
  it, and they are the reason every popover in the interface goes through here:

    * **It survives re-renders.** LiveView would hand `open` back closed on
      every patch — in a chat, with every message — so the entrypoints carry
      the browser's state into each patch (`lib/ui/popover.js`).
    * **It closes the way a menu does:** a click outside, Escape, or choosing
      an action inside it (`close_after/1`). Closing is done in the browser,
      never with `JS.remove_attribute`, which LiveView would replay on every
      later patch and so close the popover each time it was reopened.
    * **It opens where there is room.** `placement` says which edge of the
      trigger the panel hangs from; a control at the bottom of a window opens
      upwards (`above-end`), one over a video opens centred above (`above`).
      Once open, the panel is pinned to the viewport from the trigger's
      position, so a scrolling strip around the trigger cannot clip it.

  The trigger is drawn by the caller through `trigger_class` — usually
  `ToolButton.tool_button_class/1` — so it looks like every other control.

  Two things follow from the open state belonging to the browser. An `open`
  passed in only sets the initial state; later server values are not applied.
  And a popover rendered in a list needs a keyed ancestor (an `id` on its row):
  morphdom matches unkeyed siblings by position, so an open panel would move to
  the neighbouring row when one is added above it.
  """
  use RetroHexChatWeb.Component

  @placements ~w(below-end below-start above-end above-start above)

  attr :label, :string, required: true, doc: "the trigger's tooltip and accessible name"
  attr :trigger_class, :any, default: nil
  attr :trigger_testid, :string, default: nil

  attr :trigger_attrs, :list,
    default: [],
    doc: "extra attributes for the trigger, such as a hook's data-* contract"

  attr :placement, :string,
    values: @placements,
    default: "below-end",
    doc: "which edge of the trigger the panel hangs from"

  attr :panel_class, :any, default: nil
  attr :panel_role, :string, default: "group"
  attr :panel_testid, :string, default: nil
  attr :panel_attrs, :list, default: [], doc: "extra attributes for the panel"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(open)

  slot :trigger, required: true
  slot :inner_block, required: true

  @spec popover(map()) :: Phoenix.LiveView.Rendered.t()
  def popover(assigns) do
    ~H"""
    <details
      class={classes(["relative shrink-0", @class])}
      data-popover
      data-placement={@placement}
      {@rest}
    >
      <summary
        class={classes([@trigger_class, "list-none [&::-webkit-details-marker]:hidden"])}
        title={@label}
        aria-label={@label}
        data-testid={@trigger_testid}
        {@trigger_attrs}
      >
        {render_slot(@trigger)}
      </summary>
      <div
        class={classes([placement_class(@placement), @panel_class])}
        role={@panel_role}
        aria-label={@label}
        data-popover-panel
        data-testid={@panel_testid}
        {@panel_attrs}
      >
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  @doc """
  The click of an action inside a popover: run it, then close the popover it
  sits in. Takes an event name or a `%JS{}` chain.
  """
  @spec close_after(String.t() | JS.t()) :: JS.t()
  def close_after(%JS{} = js), do: JS.dispatch(js, "rhc:popover-close")
  def close_after(event) when is_binary(event), do: event |> JS.push() |> close_after()

  defp placement_class("below-end"), do: "absolute right-0 top-full z-50 mt-1"
  defp placement_class("below-start"), do: "absolute left-0 top-full z-50 mt-1"
  defp placement_class("above-end"), do: "absolute bottom-full right-0 z-50 mb-1"
  defp placement_class("above-start"), do: "absolute bottom-full left-0 z-50 mb-1"
  defp placement_class("above"), do: "absolute bottom-full left-1/2 z-50 mb-1.5 -translate-x-1/2"
end

defmodule RetroHexChatWeb.Components.UI.SpaceVirtualPad do
  @moduledoc """
  On-screen pixel-art control pad for the virtual space: a 4-direction D-pad, the
  use button (what E and F do on a keyboard: go through a gate, sit down, get
  up), the sword (attack) button and two smaller ones to wave (Q) and to start
  or stop dancing (Z), laid out the way a handheld is held: the
  action keys under the left thumb, the D-pad under the right, so mobile and
  mouse users can play without a keyboard. The floor between the two halves is
  the map's: the strip lets presses through and only its keys take them.

  Pure static markup inside the `phx-update="ignore"` space shell — all
  behavior (pointer capture, sliding between directions, press visuals) is
  wired client-side by `assets/js/lib/space/virtual_pad.js` through the same
  `InputController` the physical keyboard feeds, so a held button walks at the
  same paced cadence as a held key. Buttons are addressed by
  `data-space-pad-dir` / `data-space-pad-action`; the pressed visual is the
  `data-pressed` attribute the pad controller toggles. Buttons are
  `tabindex="-1"`: the pad is a pointer affordance — keyboard users already
  have the real keys, and stealing tab focus would fight the chat composer.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Space.PixelIcon

  @spec space_virtual_pad(map()) :: Phoenix.LiveView.Rendered.t()
  def space_virtual_pad(assigns) do
    ~H"""
    <div
      data-space-pad
      data-testid="space-virtual-pad"
      role="group"
      aria-label={dgettext("chat", "Virtual control pad")}
      class="pointer-events-none absolute inset-x-3 bottom-3 z-10 flex items-end justify-between gap-3 select-none touch-none"
    >
      <%!-- Staggered like a handheld's A and B: the thumb rolls from one to the
            other instead of reaching across. --%>
      <div class="pointer-events-auto flex items-end gap-2" data-space-pad-actions>
        <div class="flex flex-col gap-2">
          <button
            type="button"
            tabindex="-1"
            data-space-pad-action="wave"
            data-testid="space-pad-wave"
            aria-label={dgettext("chat", "Wave")}
            class="space-pad-button h-11 w-11"
          >
            <.pixel_icon name={:wave} />
          </button>
          <button
            type="button"
            tabindex="-1"
            data-space-pad-action="dance"
            data-testid="space-pad-dance"
            aria-label={dgettext("chat", "Dance")}
            class="space-pad-button h-11 w-11"
          >
            <.pixel_icon name={:dance} />
          </button>
        </div>
        <button
          type="button"
          tabindex="-1"
          data-space-pad-action="use"
          data-testid="space-pad-use"
          aria-label={dgettext("chat", "Use")}
          class="space-pad-button h-14 w-14"
        >
          <.pixel_icon name={:use} />
        </button>
        <button
          type="button"
          tabindex="-1"
          data-space-pad-action="attack"
          aria-label={dgettext("chat", "Attack")}
          class="space-pad-button space-pad-button--attack mb-8 h-14 w-14"
        >
          <.pixel_icon name={:attack} />
        </button>
      </div>
      <div class="space-pad-dpad pointer-events-auto grid grid-cols-3 grid-rows-3">
        <div></div>
        <.pad_dir_button dir="up" label={dgettext("chat", "Walk up")}>
          <.pixel_icon name={:pad_up} />
        </.pad_dir_button>
        <div></div>
        <.pad_dir_button dir="left" label={dgettext("chat", "Walk left")}>
          <.pixel_icon name={:pad_left} />
        </.pad_dir_button>
        <div></div>
        <.pad_dir_button dir="right" label={dgettext("chat", "Walk right")}>
          <.pixel_icon name={:pad_right} />
        </.pad_dir_button>
        <div></div>
        <.pad_dir_button dir="down" label={dgettext("chat", "Walk down")}>
          <.pixel_icon name={:pad_down} />
        </.pad_dir_button>
        <div></div>
      </div>
    </div>
    """
  end

  attr :dir, :string, required: true, values: ~w(up down left right)
  attr :label, :string, required: true
  attr :class, :string, default: nil
  slot :inner_block, required: true

  defp pad_dir_button(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-space-pad-dir={@dir}
      aria-label={@label}
      class={["space-pad-button h-11 w-11", @class]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end

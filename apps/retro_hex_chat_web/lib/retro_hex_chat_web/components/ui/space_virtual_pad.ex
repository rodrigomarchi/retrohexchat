defmodule RetroHexChatWeb.Components.UI.SpaceVirtualPad do
  @moduledoc """
  On-screen pixel-art control pad for the virtual space: a 4-direction D-pad, the
  use button (what E and F do on a keyboard: go through a gate, sit down, get
  up) and the sword (attack) button, anchored to the bottom-right corner of the space
  canvas so mobile and mouse users can play without a keyboard.

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
      class="absolute bottom-3 right-3 z-10 flex items-end gap-3 select-none touch-none"
    >
      <div class="space-pad-dpad grid grid-cols-3 grid-rows-3">
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
      <button
        type="button"
        tabindex="-1"
        data-space-pad-action="use"
        data-testid="space-pad-use"
        aria-label={dgettext("chat", "Use")}
        class="space-pad-button h-12 w-12"
      >
        <.pixel_icon name={:use} />
      </button>
      <button
        type="button"
        tabindex="-1"
        data-space-pad-action="attack"
        aria-label={dgettext("chat", "Attack")}
        class="space-pad-button space-pad-button--attack h-12 w-12"
      >
        <.pixel_icon name={:attack} />
      </button>
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

defmodule RetroHexChatWeb.Components.UI.SpaceVirtualPad do
  @moduledoc """
  On-screen 8-bit control pad for the virtual space: a 4-direction D-pad plus
  the sword (attack) button, anchored to the bottom-right corner of the space
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

  alias RetroHexChatWeb.Icons

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
      <div class="grid grid-cols-3 grid-rows-3">
        <div></div>
        <.pad_dir_button dir="up" label={dgettext("chat", "Walk up")} class="rounded-t-sm">
          <Icons.icon_pad_up class="h-5 w-5" />
        </.pad_dir_button>
        <div></div>
        <.pad_dir_button dir="left" label={dgettext("chat", "Walk left")} class="rounded-l-sm">
          <Icons.icon_pad_left class="h-5 w-5" />
        </.pad_dir_button>
        <div class="h-11 w-11 bg-neutral-900/80"></div>
        <.pad_dir_button dir="right" label={dgettext("chat", "Walk right")} class="rounded-r-sm">
          <Icons.icon_pad_right class="h-5 w-5" />
        </.pad_dir_button>
        <div></div>
        <.pad_dir_button dir="down" label={dgettext("chat", "Walk down")} class="rounded-b-sm">
          <Icons.icon_pad_down class="h-5 w-5" />
        </.pad_dir_button>
        <div></div>
      </div>
      <button
        type="button"
        tabindex="-1"
        data-space-pad-action="attack"
        aria-label={dgettext("chat", "Attack")}
        class="flex h-12 w-12 items-center justify-center rounded-full border border-black/70 bg-red-950/80 text-red-100 shadow-md data-[pressed]:bg-red-800/90 data-[pressed]:text-white data-[pressed]:shadow-none"
      >
        <Icons.icon_sword class="h-6 w-6" />
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
      class={[
        "flex h-11 w-11 items-center justify-center border border-black/70",
        "bg-neutral-900/80 text-neutral-200 shadow-md",
        "data-[pressed]:bg-neutral-600/90 data-[pressed]:text-white data-[pressed]:shadow-none",
        @class
      ]}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end
end

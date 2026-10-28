defmodule RetroHexChatWeb.Components.UI.SpaceVirtualPad do
  @moduledoc """
  On-screen pixel-art control pad for the virtual space: a 4-direction D-pad, the
  use button (what E and F do on a keyboard: go through a gate, sit down, get
  up), the sword (attack) button and two smaller ones to wave (Q) and to start
  or stop dancing (Z), laid out the way a handheld is held: the
  action keys under the left thumb, the D-pad under the right, so mobile and
  mouse users can play without a keyboard. The floor between the two halves is
  the map's: the strip lets presses through and only its keys take them.

  Pure static markup inside the `phx-update="ignore"` space shell, made of
  the pad pieces every pad shares (`VirtualPad`) — all
  behavior (pointer capture, sliding between directions, press visuals) is
  wired client-side by `assets/js/lib/virtual_pad.js` through the same
  `InputController` the physical keyboard feeds, so a held button walks at the
  same paced cadence as a held key. Buttons are addressed by
  `data-pad-dir` / `data-pad-action`; the pressed visual is the
  `data-pressed` attribute the pad controller toggles. Buttons are
  `tabindex="-1"`: the pad is a pointer affordance — keyboard users already
  have the real keys, and stealing tab focus would fight the chat composer.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Space.PixelIcon
  import RetroHexChatWeb.Components.UI.VirtualPad

  @spec space_virtual_pad(map()) :: Phoenix.LiveView.Rendered.t()
  def space_virtual_pad(assigns) do
    ~H"""
    <div
      data-pad
      data-testid="space-virtual-pad"
      role="group"
      aria-label={dgettext("chat", "Virtual control pad")}
      class="pointer-events-none absolute inset-x-3 bottom-3 z-10 flex items-end justify-between gap-3 select-none touch-none"
    >
      <%!-- Staggered like a handheld's A and B: the thumb rolls from one to the
            other instead of reaching across. --%>
      <div class="pointer-events-auto flex items-end gap-2" data-pad-actions>
        <div class="flex flex-col gap-2">
          <.pad_button
            action="wave"
            data-testid="space-pad-wave"
            label={dgettext("chat", "Wave")}
            class="h-11 w-11"
          >
            <.pixel_icon name={:wave} />
          </.pad_button>
          <.pad_button
            action="dance"
            data-testid="space-pad-dance"
            label={dgettext("chat", "Dance")}
            class="h-11 w-11"
          >
            <.pixel_icon name={:dance} />
          </.pad_button>
        </div>
        <.pad_button
          action="use"
          data-testid="space-pad-use"
          label={dgettext("chat", "Use")}
          class="h-14 w-14"
        >
          <.pixel_icon name={:use} />
        </.pad_button>
        <.pad_button
          action="attack"
          label={dgettext("chat", "Attack")}
          class="pad-button--attack mb-8 h-14 w-14"
        >
          <.pixel_icon name={:attack} />
        </.pad_button>
      </div>
      <.pad_cross
        class="pointer-events-auto"
        labels={
          %{
            "up" => dgettext("chat", "Walk up"),
            "down" => dgettext("chat", "Walk down"),
            "left" => dgettext("chat", "Walk left"),
            "right" => dgettext("chat", "Walk right")
          }
        }
      />
    </div>
    """
  end
end

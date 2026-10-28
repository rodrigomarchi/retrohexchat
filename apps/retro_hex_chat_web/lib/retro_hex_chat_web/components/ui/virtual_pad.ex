defmodule RetroHexChatWeb.Components.UI.VirtualPad do
  @moduledoc """
  The pieces of an on-screen pixel-art control pad, shared by the virtual
  space's pad and the Retro Games' pad under each game: a button, addressed
  by `data-pad-dir` (a direction) or `data-pad-action` (an action), and the
  cross of the directions a pad uses, on the gilded compass rose.

  The art is the space's UI kit (`.space-ui` scopes its variables and pixel
  font), so a pad's root carries that class. All behaviour — several fingers
  at once, sliding between directions, the pressed look (`data-pressed`) — is
  `assets/js/lib/virtual_pad.js`, attached to the root (`data-pad`).
  Buttons are `tabindex="-1"`: the pad is a pointer affordance, and keyboard
  users already have the real keys.
  """
  use RetroHexChatWeb, :html

  import RetroHexChatWeb.Components.UI.Space.PixelIcon

  attr :dir, :string, default: nil, values: [nil | ~w(up down left right)]
  attr :action, :string, default: nil
  attr :label, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec pad_button(map()) :: Phoenix.LiveView.Rendered.t()
  def pad_button(assigns) do
    ~H"""
    <button
      type="button"
      tabindex="-1"
      data-pad-dir={@dir}
      data-pad-action={@action}
      aria-label={@label}
      class={["pad-button", @class]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @icons %{"up" => :pad_up, "down" => :pad_down, "left" => :pad_left, "right" => :pad_right}
  @cells [nil, "up", nil, "left", nil, "right", nil, "down", nil]

  attr :dirs, :list, default: ~w(up down left right)
  attr :labels, :map, required: true, doc: "each direction's spoken name"
  attr :class, :any, default: nil

  @spec pad_cross(map()) :: Phoenix.LiveView.Rendered.t()
  def pad_cross(assigns) do
    assigns = assign(assigns, cells: @cells, icons: @icons)

    ~H"""
    <div class={["pad-cross grid grid-cols-3 grid-rows-3", @class]}>
      <%= for cell <- @cells do %>
        <.pad_button :if={cell in @dirs} dir={cell} label={@labels[cell]} class="h-11 w-11">
          <.pixel_icon name={@icons[cell]} />
        </.pad_button>
        <div :if={cell not in @dirs}></div>
      <% end %>
    </div>
    """
  end
end

defmodule RetroHexChatWeb.Components.UI.Button do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Renders a retro button with an optional icon.

  Icons are the default expectation for action buttons but may be
  omitted for structural/micro buttons (dismiss, tab-close, Send, etc.).

  ## Examples

      <.button>
        <:icon><svg ...></.svg></:icon>
        Save
      </.button>

      <.button variant="outline" size="sm">
        Retry
      </.button>
  """
  attr :type, :string, default: nil
  attr :class, :any, default: nil

  attr :variant, :string,
    values: ~w(default secondary destructive outline ghost link),
    default: "default",
    doc: "the button variant style"

  attr :size, :string, values: ~w(default sm lg icon), default: "default"
  attr :rest, :global, include: ~w(disabled form name value)

  slot :icon, required: true, doc: "16×16 icon SVG — mandatory for all buttons"
  slot :inner_block, required: true

  def button(assigns) do
    assigns = assign(assigns, :variant_class, button_variant(assigns))

    ~H"""
    <button
      type={@type}
      class={
        classes([
          @variant_class,
          "gap-retro-4",
          @class
        ])
      }
      {@rest}
    >
      <span class="w-[16px] h-[16px] shrink-0 inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      {render_slot(@inner_block)}
    </button>
    """
  end
end

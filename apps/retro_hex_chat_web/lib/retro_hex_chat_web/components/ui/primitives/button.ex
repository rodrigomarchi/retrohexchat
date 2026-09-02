defmodule RetroHexChatWeb.Components.UI.Button do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Renders a retro button with a mandatory 16×16 icon.

  Every button must provide a `:icon` slot for Win98 visual consistency.

  ## Examples

      <.button>
        <:icon><Icons.icon_btn_save /></:icon>
        Save
      </.button>

      <.button variant="outline" size="sm">
        <:icon><Icons.icon_retry /></:icon>
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

  attr :navigate, :string,
    default: nil,
    doc: "renders a link that looks like a button — for an action that is a destination"

  attr :href, :string, default: nil, doc: "same, for a plain browser navigation"
  attr :rest, :global, include: ~w(disabled form name value target rel)

  slot :icon, required: true, doc: "16×16 icon SVG — mandatory for all buttons"
  slot :inner_block, required: true

  def button(assigns) do
    assigns = assign(assigns, :variant_class, button_variant(assigns))

    if assigns.navigate || assigns.href do
      button_link(assigns)
    else
      plain_button(assigns)
    end
  end

  # An action whose result is a different page is a link, and has to be one:
  # middle-click, open-in-new-tab and the status bar all come from the anchor,
  # not from the styling. Sharing the variant classes is what keeps it from
  # being a second look-alike button.
  defp button_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      href={@href}
      class={classes([@variant_class, "gap-retro-4", @class])}
      {@rest}
    >
      <span class="w-[16px] h-[16px] shrink-0 inline-flex items-center justify-center">
        {render_slot(@icon)}
      </span>
      {render_slot(@inner_block)}
    </.link>
    """
  end

  defp plain_button(assigns) do
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

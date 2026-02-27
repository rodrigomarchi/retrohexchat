defmodule RetroHexChatWeb.Components.UI.Tooltip do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc """
  Render a tooltip

  ## Examples:

  <.tooltip>
    <.button variant="outline">Hover me</.button>
    <.tooltip_content class="bg-primary text-white" theme={nil}>
     <p>Hi! I'm a tooltip.</p>
    </.tooltip_content>
  </.tooltip>

  """
  attr :class, :string, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <div
      class={
        classes([
          "relative group/tooltip inline-block",
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Render only for compatible with shad ui
  """
  slot :inner_block, required: true

  def tooltip_trigger(assigns) do
    ~H"""
    {render_slot(@inner_block)}
    """
  end

  @doc """
  Render
  """
  attr :class, :string, default: nil
  attr :side, :string, default: "top", values: ~w(bottom left right top)
  attr :rest, :global
  slot :inner_block, required: true

  def tooltip_content(assigns) do
    assigns =
      assign(assigns, :variant_class, side_variant(assigns.side))

    ~H"""
    <div
      data-side={@side}
      class={
        classes([
          "tooltip-content absolute whitespace-nowrap hidden group-hover/tooltip:block",
          "z-50 w-auto overflow-hidden border-none shadow-retro-window bg-tooltip-bg px-3 py-1.5 text-sm text-foreground",
          @variant_class,
          @class
        ])
      }
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end

defmodule RetroHexChatWeb.Components.UI.Fieldset do
  @moduledoc false
  use RetroHexChatWeb.Component

  @doc "Renders a Win98-style fieldset (groupbox) with etched groove border."
  attr :legend, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec retro_fieldset(map()) :: Phoenix.LiveView.Rendered.t()
  def retro_fieldset(assigns) do
    ~H"""
    <fieldset class={classes(["retro-fieldset p-4 pt-2 m-0", @class])} {@rest}>
      <legend :if={@legend} class="bg-surface px-1 text-sm font-bold">{@legend}</legend>
      {render_slot(@inner_block)}
    </fieldset>
    """
  end

  @doc "Renders a horizontal form row within a fieldset."
  attr :class, :any, default: nil
  attr :stacked, :boolean, default: false
  attr :rest, :global
  slot :inner_block, required: true

  @spec field_row(map()) :: Phoenix.LiveView.Rendered.t()
  def field_row(assigns) do
    ~H"""
    <div
      class={
        classes([
          if(@stacked,
            do: "flex flex-col gap-1",
            else: "flex items-center gap-2"
          ),
          "mt-1.5 first:mt-0",
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

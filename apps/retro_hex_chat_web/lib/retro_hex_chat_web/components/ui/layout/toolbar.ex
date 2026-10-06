defmodule RetroHexChatWeb.Components.UI.Toolbar do
  @moduledoc """
  The Win98 toolbar strip. Its buttons and separators are
  `RetroHexChatWeb.Components.UI.ToolButton`.
  """
  use RetroHexChatWeb.Component

  @doc "Renders a Win98-style toolbar container."
  attr :variant, :string, values: ~w(default compact), default: "default"
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div
      class={classes(["flex items-center bg-surface", @class])}
      role="toolbar"
      data-variant={@variant}
      {@rest}
    >
      {render_slot(@inner_block)}
    </div>
    """
  end
end

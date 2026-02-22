defmodule RetroHexChatWeb.Components.Window do
  @moduledoc """
  Retro window wrapper component with title bar and borders.
  """
  use Phoenix.Component

  attr :title, :string, required: true
  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  @spec window(map()) :: Phoenix.LiveView.Rendered.t()
  def window(assigns) do
    ~H"""
    <div class={"window #{@class}"} {@rest}>
      <div class="title-bar">
        <div class="title-bar-text">{@title}</div>
        <div class="title-bar-controls">
          <button aria-label="Minimize"></button>
          <button aria-label="Maximize"></button>
          <button aria-label="Close"></button>
        </div>
      </div>
      <div class="window-body">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end

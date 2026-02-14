defmodule RetroHexChatWeb.Components.ScrollLoader do
  @moduledoc """
  Phoenix component showing a 98.css progress indicator when loading older messages.
  """
  use Phoenix.Component

  attr :loading, :boolean, default: false

  @spec scroll_loader(map()) :: Phoenix.LiveView.Rendered.t()
  def scroll_loader(assigns) do
    ~H"""
    <div :if={@loading} class="scroll-loader">
      <div role="progressbar" class="animate">
        <div></div>
      </div>
      <span>Loading messages...</span>
    </div>
    """
  end
end

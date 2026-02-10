defmodule RetroHexChatWeb.Components.TitleBar do
  @moduledoc """
  Title bar component for the main application window.
  """
  use Phoenix.Component

  attr :title, :string, default: "RetroHexChat"

  @spec title_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def title_bar(assigns) do
    ~H"""
    <div class="title-bar app-title-bar">
      <div class="title-bar-text">{@title}</div>
      <div class="title-bar-controls">
        <button aria-label="Minimize"></button>
        <button aria-label="Maximize"></button>
        <button aria-label="Close"></button>
      </div>
    </div>
    """
  end
end

defmodule RetroHexChatWeb.Components.LoadingSpinner do
  @moduledoc """
  Centered loading spinner with 98.css-styled progress bar.

  Shown while channel message history is loading. Non-blocking (pointer-events: none).
  """
  use Phoenix.Component

  attr :loading, :boolean, required: true
  attr :text, :string, default: "Loading messages..."
  attr :timeout, :boolean, default: false

  @spec loading_spinner(map()) :: Phoenix.LiveView.Rendered.t()
  def loading_spinner(assigns) do
    ~H"""
    <div :if={@loading} class="loading-spinner" data-testid="loading-spinner">
      <div class="loading-spinner__bar" role="progressbar"></div>
      <span class="loading-spinner__text">{@text}</span>
      <button :if={@timeout} class="loading-spinner__retry" phx-click="retry_load_messages">
        Retry
      </button>
    </div>
    """
  end
end

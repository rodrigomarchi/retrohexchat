defmodule RetroHexChatWeb.Components.ConnectionStatus do
  @moduledoc """
  Unified connection status component: banner + reconnect overlay.

  Pre-renders the DOM structure for both the brief-disconnect banner and
  the fullscreen reconnect overlay. All runtime state transitions are
  managed client-side by `ConnectionStatusHook`.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons

  @spec connection_status(map()) :: Phoenix.LiveView.Rendered.t()
  def connection_status(assigns) do
    ~H"""
    <div id="connection-status" phx-hook="ConnectionStatusHook" data-testid="connection-status">
      <div class="connection-banner" data-role="banner">
        <span data-role="banner-text"></span>
      </div>

      <div class="reconnect-overlay" data-role="overlay">
        <div class="window">
          <div class="title-bar">
            <Icons.icon_btn_disconnect class="title-bar-icon" />
            <div class="title-bar-text">Connection Lost</div>
          </div>
          <div class="window-body">
            <p data-role="overlay-info" class="attempt-info"></p>
            <p data-role="overlay-countdown" class="countdown"></p>
            <div class="u-mt-12">
              <button data-role="overlay-action" class="btn-icon"></button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end

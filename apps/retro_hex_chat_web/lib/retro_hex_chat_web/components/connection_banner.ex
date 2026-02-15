defmodule RetroHexChatWeb.Components.ConnectionBanner do
  @moduledoc """
  Connection status banner for brief disconnection/reconnection feedback.

  Shows a red banner during brief disconnections and a green banner on reconnection.
  All state management is handled client-side by ConnectionBannerHook.
  """
  use Phoenix.Component

  @spec connection_banner(map()) :: Phoenix.LiveView.Rendered.t()
  def connection_banner(assigns) do
    ~H"""
    <div
      id="connection-banner"
      class="connection-banner"
      phx-hook="ConnectionBannerHook"
      data-testid="connection-banner"
    >
    </div>
    """
  end
end

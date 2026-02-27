defmodule RetroHexChatWeb.Components.UI.ConnectionStatus do
  @moduledoc """
  Connection status component for the showcase design system.

  Composed from alert + button + loading_spinner primitives.
  Connection banner with states: connected, reconnecting, disconnected.

  ## Usage

      <.connection_status state="reconnecting" attempt={3} max_attempts={5} />
  """
  use RetroHexChatWeb.Component

  import RetroHexChatWeb.Components.UI.Alert
  import RetroHexChatWeb.Components.UI.Button
  import RetroHexChatWeb.Components.UI.LoadingSpinner

  alias RetroHexChatWeb.Icons

  @doc "Renders the connection status banner."
  attr :state, :string, default: "connected", values: ~w(connected reconnecting disconnected)
  attr :server, :string, default: nil
  attr :attempt, :integer, default: 0
  attr :max_attempts, :integer, default: 5
  attr :class, :string, default: nil
  attr :rest, :global

  @spec connection_status(map()) :: Phoenix.LiveView.Rendered.t()
  def connection_status(assigns) do
    ~H"""
    <div class={@class} {@rest}>
      <.connection_connected :if={@state == "connected"} server={@server} />
      <.connection_reconnecting
        :if={@state == "reconnecting"}
        attempt={@attempt}
        max_attempts={@max_attempts}
      />
      <.connection_disconnected :if={@state == "disconnected"} />
    </div>
    """
  end

  # ── Connected ─────────────────────────────────────────

  attr :server, :string, default: nil

  defp connection_connected(assigns) do
    ~H"""
    <.alert>
      <div class="flex items-center gap-retro-4">
        <Icons.icon_status_signal class="w-4 h-4 text-success" />
        <.alert_title>Connected</.alert_title>
      </div>
      <.alert_description :if={@server}>
        Connected to {@server}
      </.alert_description>
    </.alert>
    """
  end

  # ── Reconnecting ─────────────────────────────────────

  attr :attempt, :integer, required: true
  attr :max_attempts, :integer, required: true

  defp connection_reconnecting(assigns) do
    ~H"""
    <.alert variant="destructive">
      <div class="flex items-center gap-retro-4">
        <.loading_spinner size="sm" text="" />
        <.alert_title>Reconnecting...</.alert_title>
      </div>
      <.alert_description>
        Attempt {@attempt} of {@max_attempts}
      </.alert_description>
    </.alert>
    """
  end

  # ── Disconnected ─────────────────────────────────────

  defp connection_disconnected(assigns) do
    ~H"""
    <.alert variant="destructive">
      <div class="flex items-center gap-retro-4">
        <Icons.icon_close class="w-4 h-4" />
        <.alert_title>Disconnected</.alert_title>
      </div>
      <.alert_description>
        <div class="flex items-center gap-retro-4 mt-retro-4">
          <span>Connection lost.</span>
          <.button size="sm" variant="outline">
            <:icon><Icons.icon_status_signal class="w-4 h-4" /></:icon>
            Reconnect
          </.button>
        </div>
      </.alert_description>
    </.alert>
    """
  end
end

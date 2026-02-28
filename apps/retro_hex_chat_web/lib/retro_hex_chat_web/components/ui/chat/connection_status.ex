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
  attr :visible, :boolean, default: true, doc: "Show/hide the banner"
  attr :on_retry, :any, default: nil, doc: "Reconnect button callback"
  attr :on_dismiss, :any, default: nil, doc: "Dismiss banner callback"
  attr :class, :string, default: nil
  attr :rest, :global

  @spec connection_status(map()) :: Phoenix.LiveView.Rendered.t()
  def connection_status(assigns) do
    ~H"""
    <div :if={@visible} class={@class} data-testid={"connection-status-#{@state}"} {@rest}>
      <.connection_connected :if={@state == "connected"} server={@server} on_dismiss={@on_dismiss} />
      <.connection_reconnecting
        :if={@state == "reconnecting"}
        attempt={@attempt}
        max_attempts={@max_attempts}
      />
      <.connection_disconnected :if={@state == "disconnected"} on_retry={@on_retry} />
    </div>
    """
  end

  # ── Connected ─────────────────────────────────────────

  attr :server, :string, default: nil
  attr :on_dismiss, :any, default: nil

  defp connection_connected(assigns) do
    ~H"""
    <.alert>
      <div class="flex items-center gap-retro-4">
        <Icons.icon_status_signal class="w-4 h-4 text-success" />
        <.alert_title class="flex-1">Connected</.alert_title>
        <button
          :if={@on_dismiss}
          type="button"
          class="text-xs hover:bg-black/10 px-1"
          phx-click={@on_dismiss}
          aria-label="Dismiss"
        >
          ×
        </button>
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

  attr :on_retry, :any, default: nil

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
          <.button
            size="sm"
            variant="outline"
            phx-click={@on_retry}
            data-testid="connection-status-reconnect"
          >
            <:icon><Icons.icon_status_signal class="w-4 h-4" /></:icon>
            Reconnect
          </.button>
        </div>
      </.alert_description>
    </.alert>
    """
  end
end

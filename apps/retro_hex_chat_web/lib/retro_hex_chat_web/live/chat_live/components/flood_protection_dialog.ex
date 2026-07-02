defmodule RetroHexChatWeb.ChatLive.Components.FloodProtectionDialog do
  @moduledoc """
  The Flood Protection window body.

  Uses an **uncontrolled** form: the three fieldsets submit their fields directly
  via `phx-submit`, so there is no per-keystroke draft to hold (adding one would
  mean a server round-trip on every change). The component takes `settings` (from
  `session.flood_protection`) and `visible` from the parent, and the
  save/reset/cancel events are handled on the parent's `SettingsDialogsEvents`,
  which reads the submitted params, writes the session, and closes the
  server-managed window (unmounting this island).
  """
  use RetroHexChatWeb, :live_component

  import RetroHexChatWeb.Components.UI.FloodProtectionDialog

  @id "flood-protection-dialog"

  @doc "Stable DOM/component id."
  @spec id() :: String.t()
  def id, do: @id

  @impl true
  @spec mount(Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def mount(socket) do
    {:ok, assign(socket, id: @id, settings: %{})}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok, assign(socket, settings: Map.get(assigns, :settings, socket.assigns.settings))}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"} class="contents">
      <.flood_protection_panel
        id={@id}
        settings={@settings}
        on_save="flood_save_settings"
        on_reset="flood_reset_defaults"
        on_cancel="close_flood_protection_dialog"
      />
    </div>
    """
  end
end

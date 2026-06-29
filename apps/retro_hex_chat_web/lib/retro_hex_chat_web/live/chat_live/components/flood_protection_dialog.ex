defmodule RetroHexChatWeb.ChatLive.Components.FloodProtectionDialog do
  @moduledoc """
  The Flood Protection settings dialog.

  Uses an **uncontrolled** form: the three fieldsets submit their fields directly
  via `phx-submit`, so there is no per-keystroke draft to hold (adding one would
  mean a server round-trip on every change). The component takes `settings` (from
  `session.flood_protection`) and `visible` from the parent, and the
  save/reset/cancel events are handled on the parent's `SettingsDialogsEvents`,
  which reads the submitted params, writes the session, and toggles visibility.

  The parent holds `show_flood_protection_dialog` because it is Escape-managed in
  `keyboard_events.ex`; it is passed in here as `visible`.
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
    {:ok, assign(socket, id: @id, visible: false, settings: %{})}
  end

  @impl true
  @spec update(map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
  def update(assigns, socket) do
    {:ok,
     assign(socket,
       visible: Map.get(assigns, :visible, socket.assigns.visible),
       settings: Map.get(assigns, :settings, socket.assigns.settings)
     )}
  end

  @impl true
  @spec render(map()) :: Phoenix.LiveView.Rendered.t()
  def render(assigns) do
    ~H"""
    <div id={"#{@id}-mount"}>
      <.flood_protection_dialog
        id={@id}
        show={@visible}
        settings={@settings}
        on_save="flood_save_settings"
        on_reset="flood_reset_defaults"
        on_cancel="close_flood_protection_dialog"
      />
    </div>
    """
  end
end

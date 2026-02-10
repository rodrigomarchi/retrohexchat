defmodule RetroHexChatWeb.Components.Toolbar do
  @moduledoc """
  Toolbar with Connect/Disconnect, Channel List, Settings buttons.
  """
  use Phoenix.Component

  attr :connected, :boolean, default: false

  @spec toolbar(map()) :: Phoenix.LiveView.Rendered.t()
  def toolbar(assigns) do
    ~H"""
    <div class="toolbar" role="toolbar">
      <button :if={@connected} type="button" class="toolbar-btn" phx-click="disconnect">
        Disconnect
      </button>
      <button :if={!@connected} type="button" class="toolbar-btn" phx-click="connect">
        Connect
      </button>
      <button type="button" class="toolbar-btn" phx-click="channel_list">Channel List</button>
      <button type="button" class="toolbar-btn" phx-click="settings">Settings</button>
    </div>
    """
  end
end

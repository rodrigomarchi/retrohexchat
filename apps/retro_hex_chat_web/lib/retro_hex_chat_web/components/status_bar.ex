defmodule RetroHexChatWeb.Components.StatusBar do
  @moduledoc """
  Status bar showing nickname, active channel, user count, connection status.
  """
  use Phoenix.Component

  attr :nickname, :string, required: true
  attr :channel, :string, default: nil
  attr :user_count, :integer, default: 0
  attr :connected, :boolean, default: true

  @spec status_bar(map()) :: Phoenix.LiveView.Rendered.t()
  def status_bar(assigns) do
    ~H"""
    <div class="status-bar">
      <p class="status-bar-field">{@nickname}</p>
      <p class="status-bar-field">{@channel || "No channel"}</p>
      <p class="status-bar-field">Users: {@user_count}</p>
      <p class="status-bar-field">
        {if @connected, do: "Connected", else: "Disconnected"}
      </p>
    </div>
    """
  end
end

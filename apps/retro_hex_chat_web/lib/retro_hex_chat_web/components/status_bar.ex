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
      <p class="status-bar-field" data-testid="status-nick">{@nickname}</p>
      <p class="status-bar-field" data-testid="status-channel">{@channel || "No channel"}</p>
      <p class="status-bar-field" data-testid="status-users">Users: {@user_count}</p>
      <p class="status-bar-field" data-testid="status-connection">
        {if @connected, do: "Connected", else: "Disconnected"}
      </p>
    </div>
    """
  end
end

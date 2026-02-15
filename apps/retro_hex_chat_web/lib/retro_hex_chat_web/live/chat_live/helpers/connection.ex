defmodule RetroHexChatWeb.ChatLive.Helpers.Connection do
  @moduledoc """
  Connection state helpers: ping/pong latency measurement, lag status classification.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  @type lag_status :: :normal | :warning | :critical | :timeout

  @doc """
  Classify a lag measurement into a status level.

  ## Thresholds
    - normal: 0-199ms
    - warning: 200-499ms
    - critical: 500ms+
    - timeout: nil (no response)
  """
  @spec lag_status(non_neg_integer() | nil) :: lag_status()
  def lag_status(nil), do: :timeout
  def lag_status(ms) when ms < 200, do: :normal
  def lag_status(ms) when ms < 500, do: :warning
  def lag_status(_ms), do: :critical

  @doc """
  Handle ping event from client. Echoes the client_time back as a pong.
  """
  @spec handle_ping(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def handle_ping(socket, %{"client_time" => client_time}) do
    push_event(socket, "pong", %{client_time: client_time})
  end

  @doc """
  Handle lag_update event from client. Updates lag_ms and lag_status assigns.
  """
  @spec handle_lag_update(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def handle_lag_update(socket, %{"lag_ms" => lag_ms}) do
    socket
    |> assign(:lag_ms, lag_ms)
    |> assign(:lag_status, lag_status(lag_ms))
  end
end

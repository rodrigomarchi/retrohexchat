defmodule RetroHexChatWeb.ChatLive.Helpers.Connection do
  @moduledoc """
  Connection state helpers: ping/pong latency measurement, lag status classification.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  alias RetroHexChat.Accounts.TrustedDevices

  @type lag_status :: :normal | :warning | :critical | :timeout
  @touch_interval_seconds 60

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
    socket
    |> maybe_touch_device_session()
    |> push_event("pong", %{client_time: client_time})
  end

  def handle_ping(socket, _params), do: socket

  @doc """
  Handle lag_update event from client. Updates lag_ms and lag_status assigns.
  """
  @spec handle_lag_update(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def handle_lag_update(socket, %{"lag_ms" => lag_ms}) do
    socket
    |> assign(:lag_ms, lag_ms)
    |> assign(:lag_status, lag_status(lag_ms))
  end

  def handle_lag_update(socket, _params), do: socket

  defp maybe_touch_device_session(socket) do
    session_ref = socket.assigns[:chat_device_session_ref]
    last_touch = socket.assigns[:last_device_session_touch_at]
    now = DateTime.utc_now()

    if session_ref && touch_due?(last_touch, now) do
      TrustedDevices.touch_session(session_ref)
      assign(socket, :last_device_session_touch_at, now)
    else
      socket
    end
  end

  defp touch_due?(nil, _now), do: true

  defp touch_due?(%DateTime{} = last_touch, now) do
    DateTime.diff(now, last_touch, :second) >= @touch_interval_seconds
  end

  defp touch_due?(_last_touch, _now), do: true
end

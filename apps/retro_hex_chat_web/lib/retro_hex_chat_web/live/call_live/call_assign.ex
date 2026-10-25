defmodule RetroHexChatWeb.CallLive.CallAssign do
  @moduledoc """
  The conference's state on this page — the `group_call` assign — and the
  push that tells the browser how to lay its tiles out after it changes.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_event: 3]

  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.CallLive.Layout

  @doc "Applies `fun` to the `group_call` assign."
  @spec update(Socket.t(), (map() -> map())) :: Socket.t()
  def update(socket, fun) do
    assign(socket, group_call: fun.(socket.assigns.group_call))
  end

  @doc "Tells the browser the layout, participants and tracks to draw; nothing outside a call."
  @spec push_layout(Socket.t()) :: Socket.t()
  def push_layout(%{assigns: %{group_call: call}} = socket) when is_map(call) do
    push_event(socket, "group_call_layout_state", Layout.group_call_layout_payload(call))
  end

  def push_layout(socket), do: socket

  @doc "`push_layout/1`, in speaker mode only, where who is speaking moves the focus."
  @spec push_speaker_layout(Socket.t()) :: Socket.t()
  def push_speaker_layout(%{assigns: %{group_call: %{layout: %{mode: :speaker}}}} = socket),
    do: push_layout(socket)

  def push_speaker_layout(socket), do: socket
end

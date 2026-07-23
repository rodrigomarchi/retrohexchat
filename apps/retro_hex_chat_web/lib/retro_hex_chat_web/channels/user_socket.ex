defmodule RetroHexChatWeb.UserSocket do
  @moduledoc """
  Raw Phoenix socket for realtime channels that live outside LiveView.

  The socket itself is anonymous: authorization happens per channel via a
  signed join token (see `RetroHexChat.VirtualSpace.ChannelJoinToken`), so
  `connect/3` accepts everyone and never identifies the transport.
  """
  use Phoenix.Socket, log: :debug

  channel "space:*", RetroHexChatWeb.SpaceChannel
  channel "group_call:*", RetroHexChatWeb.GroupCallChannel

  @impl true
  @spec connect(map(), Phoenix.Socket.t(), map()) :: {:ok, Phoenix.Socket.t()}
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  @impl true
  @spec id(Phoenix.Socket.t()) :: nil
  def id(_socket), do: nil
end

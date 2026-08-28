defmodule RetroHexChatWeb.CallLive.Host do
  @moduledoc """
  Where a call surface's side effects land, which is the one thing that differs
  between its two mounts.

  The conference is a single LiveView with two hosts: a child of the chat's
  desktop, and a page of its own at `/call/:token`. Everything about being in a
  call is identical across the two. Three things cannot be:

    * **a notice.** Inside the chat, "you cannot mute an operator" belongs in
      the conversation, where every other refusal in this product already
      appears. A tab opened from a shared link has no conversation, so it says
      it on its own status bar. Both are the same sentence; only the surface
      that shows it differs.
    * **the window.** Embedded, the window belongs to the chat's manager and
      the surface asks it to focus or drop it. Standalone, the window is the
      page, and there is nothing to ask.
    * **what the host shows about the call.** The chat draws a taskbar button
      and a status-bar zone for a call it does not own any more, so the surface
      hands it the little it needs and keeps the rest.

  The channel between them is the parent process, not PubSub: a child
  `live_render` has exactly one host, it dies with it, and a topic would carry
  this to every tab the person has open — which is the cross-tab problem, and
  it has a wave of its own.
  """

  import Phoenix.Component, only: [assign: 2]
  import Phoenix.LiveView, only: [push_navigate: 2]

  alias Phoenix.LiveView.Socket
  alias RetroHexChatWeb.App.Paths

  @doc "A refusal or a failure, in the words the policy used."
  @spec error(Socket.t(), String.t()) :: Socket.t()
  def error(socket, message), do: notice(socket, :error, message)

  @doc "Something that happened, worth recording where the person is reading."
  @spec system(Socket.t(), String.t()) :: Socket.t()
  def system(socket, message), do: notice(socket, :system, message)

  defp notice(%{assigns: %{embedded?: true}} = socket, kind, message) do
    send(socket.parent_pid, {:call_surface_notice, kind, message})
    socket
  end

  defp notice(socket, kind, message) do
    assign(socket, notice: %{kind: kind, message: message})
  end

  @doc "Bring the call to the front of whatever is hosting it."
  @spec focus(Socket.t()) :: Socket.t()
  def focus(%{assigns: %{embedded?: true}} = socket) do
    send(socket.parent_pid, :call_surface_focus)
    socket
  end

  def focus(socket), do: socket

  @doc """
  The call is over and the surface should leave the screen.

  Embedded, that is the host's window to take down. Standalone, the page has
  nowhere to stay, so it goes where every surface's way out points: the chat.
  """
  @spec close(Socket.t()) :: Socket.t()
  def close(%{assigns: %{embedded?: true}} = socket) do
    send(socket.parent_pid, :call_surface_closed)
    socket
  end

  def close(socket), do: push_navigate(socket, to: Paths.chat_path(socket))

  @doc """
  Hand the host the little it draws about the call: which channel, what state,
  and who is in it.

  Sent only when it changes — the chat repaints a taskbar button and a status
  zone from this, and neither moves when a track is renegotiated.
  """
  @spec publish(Socket.t()) :: Socket.t()
  def publish(socket) do
    snapshot = snapshot(socket)

    if snapshot == socket.assigns[:host_snapshot] do
      socket
    else
      if socket.assigns[:embedded?] do
        send(socket.parent_pid, {:call_surface_state, self(), snapshot})
      end

      assign(socket, host_snapshot: snapshot)
    end
  end

  @doc """
  What the host is told about the call — public so its shape is testable.

  Nicknames and track ids, not participants and tracks: the chat's title bar,
  taskbar button and status zone count them and name the channel, and nothing
  in the chat reads a media state it is not carrying.
  """
  @spec snapshot(Socket.t()) :: map() | nil
  def snapshot(%{assigns: %{group_call: %{} = call}}) do
    %{
      channel_name: call.channel_name,
      status: call.status,
      participants: Enum.map(call.participants || [], &%{nickname: Map.get(&1, :nickname)}),
      tracks: Enum.map(call.tracks || [], &%{id: Map.get(&1, :id)})
    }
  end

  def snapshot(%{assigns: %{group_call_prejoin: %{channel_name: channel_name}}}) do
    %{channel_name: channel_name, status: :prejoin, participants: [], tracks: []}
  end

  def snapshot(_socket), do: nil
end

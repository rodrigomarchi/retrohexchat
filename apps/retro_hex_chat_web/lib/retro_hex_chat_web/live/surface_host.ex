defmodule RetroHexChatWeb.Live.SurfaceHost do
  @moduledoc """
  Where a surface's side effects land, which is the one thing that differs
  between its two mounts.

  A surface is a single LiveView with two hosts: a child of the chat's desktop,
  and a page of its own. Everything about being inside it is identical across
  the two. Three things cannot be, and each of them is a message to the parent
  when there is one and something drawn here when there is not:

    * **a notice.** Inside the chat, "you cannot mute an operator" belongs in
      the conversation, where every other refusal in this product already
      appears. A tab opened from a shared link has no conversation, so it says
      it on its own status bar. Both are the same sentence; only the surface
      that shows it differs.
    * **the window.** Embedded, the window belongs to the chat's manager and
      the surface asks it to focus or drop it. Standalone, the window is the
      page, and there is nothing to ask.
    * **what the host shows about it.** The chat draws a taskbar button and a
      status-bar zone for something it does not own any more, so the surface
      hands it the little it needs and keeps the rest.

  The channel between them is the parent process, not PubSub: a child
  `live_render` has exactly one host, it dies with it, and a topic would carry
  this to every tab the person has open — which is the cross-tab problem, and
  it has a wave of its own.

  This was `CallLive.Host` while the conference was the only surface with all
  three. The P2P session is the second, and it has all three as well; the space
  has none of them, which is why it was never promoted for two.

  Every message carries the surface's own tag, assigned as `:surface_tag` at
  mount. A host that renders two surfaces at once — the chat renders the
  conference and the P2P session in different windows — reads its own name off
  the message rather than guessing from the shape.
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
    send(socket.parent_pid, {:surface_notice, tag(socket), kind, message})
    socket
  end

  defp notice(socket, kind, message) do
    assign(socket, notice: %{kind: kind, message: message})
  end

  @doc "Bring the surface to the front of whatever is hosting it."
  @spec focus(Socket.t()) :: Socket.t()
  def focus(%{assigns: %{embedded?: true}} = socket) do
    send(socket.parent_pid, {:surface_focus, tag(socket)})
    socket
  end

  def focus(socket), do: socket

  @doc """
  The surface is finished and should leave the screen.

  Embedded, that is the host's window to take down. Standalone, the page has
  nowhere to stay, so it goes where every surface's way out points: the chat.
  """
  @spec close(Socket.t()) :: Socket.t()
  def close(%{assigns: %{embedded?: true}} = socket) do
    send(socket.parent_pid, {:surface_closed, tag(socket)})
    socket
  end

  def close(socket), do: push_navigate(socket, to: Paths.chat_path())

  @doc """
  Ask the host to resize the window it keeps this surface in.

  A size belongs to the window manager, and a surface that is the page has no
  window manager: standalone this is nothing, and that is not a missing
  feature — a page resizing itself would be a tab fighting the browser.
  """
  @spec geometry(Socket.t(), map()) :: Socket.t()
  def geometry(%{assigns: %{embedded?: true}} = socket, geometry) do
    send(socket.parent_pid, {:surface_geometry, tag(socket), geometry})
    socket
  end

  def geometry(socket, _geometry), do: socket

  @doc """
  Hand the host the little it draws about this surface.

  Sent only when it changes — the chat repaints a taskbar button and a status
  zone from this, and neither moves when a track is renegotiated.
  """
  @spec publish(Socket.t(), map() | nil) :: Socket.t()
  def publish(socket, snapshot) do
    if snapshot == socket.assigns[:host_snapshot] do
      socket
    else
      if socket.assigns[:embedded?] do
        send(socket.parent_pid, {:surface_state, tag(socket), self(), snapshot})
      end

      assign(socket, host_snapshot: snapshot)
    end
  end

  defp tag(socket), do: socket.assigns[:surface_tag]
end

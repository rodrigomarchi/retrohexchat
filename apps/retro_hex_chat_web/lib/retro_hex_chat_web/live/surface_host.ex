defmodule RetroHexChatWeb.Live.SurfaceHost do
  @moduledoc """
  Where a surface's side effects land, which is the one thing that differs
  between its two mounts.

  A surface is a single LiveView with two hosts: a child of the chat's desktop,
  and a page of its own. Everything about being inside it is identical across
  the two. Four things cannot be, and each of them is a message to the parent
  when there is one and something drawn here when there is not:

    * **a notice.** Inside the chat, "you cannot mute an operator" belongs in
      the conversation, where every other refusal in this product already
      appears. A tab opened from a shared link has no conversation, so it says
      it on its own status bar. Both are the same sentence; only the surface
      that shows it differs.
    * **the window.** Embedded, the window belongs to the chat's manager and
      the surface asks it to focus or drop it. Standalone, the window is the
      page: dropping it marks the surface finished and leaves the way back to
      the link that knows how to reach a chat tab already open, because
      *navigating* to the chat would announce a second chat session and end the
      first.
    * **what the host shows about it.** The chat draws a taskbar button and a
      status-bar zone for something it does not own any more, so the surface
      hands it the little it needs and keeps the rest.
    * **what outlives it.** A choice made in a surface's antechamber belongs to
      the person, and the surface holding it is torn down every time they back
      out. Embedded, the host is what is still standing afterwards, so it keeps
      that choice for the next open; standalone, backing out leaves the page
      and there is no next open to keep it for.

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

  alias Phoenix.LiveView.Socket
  alias RetroHexChat.Surfaces

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

  # Standalone, leaving is **not** navigating to `/chat`. Mounting the chat is
  # announcing a chat session, and a chat session announces a takeover — so
  # going "back" by navigation ended the chat this person already had open, in
  # another tab, that they never asked to leave. Measured: cancelling the
  # antechamber left the original chat sitting on
  # `/connect?reason=Session ended — logged in from another window`.
  #
  # The surface says it is finished instead, and the way back is the same
  # `back_to_chat` every surface already draws — a request for the tab that
  # exists, and a plain link only when there is none.
  def close(socket) do
    _ = release_address(socket)
    assign(socket, surface_left: true)
  end

  # The tab is still open and still counts for the membership rule; it is just
  # not somewhere to send anybody any more.
  defp release_address(socket) do
    case socket.assigns[:surface_nickname] || socket.assigns[:nickname] do
      nickname when is_binary(nickname) and nickname != "" -> Surfaces.release(nickname)
      _anonymous -> :ok
    end
  end

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

  @doc """
  Leave a choice with the host, to be handed back the next time the surface
  opens.

  The payload crosses a `live_render` session on the way back, so it must be
  plain data — string keys and string values, never atoms the far side would
  have to conjure.
  """
  @spec remember(Socket.t(), map()) :: Socket.t()
  def remember(%{assigns: %{embedded?: true}} = socket, preferences) do
    send(socket.parent_pid, {:surface_preferences, tag(socket), preferences})
    socket
  end

  def remember(socket, _preferences), do: socket

  defp tag(socket), do: socket.assigns[:surface_tag]
end

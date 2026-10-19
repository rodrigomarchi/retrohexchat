defmodule RetroHexChatWeb.SpectateChannel do
  @moduledoc """
  A P2P match relayed to the people watching it, `spectate:<session_token>`.

  The two players' browsers exchange the match over a DataChannel the server
  never sees. Watching needs the same bytes the guest draws, so the host sends
  a thinned copy of what it sends its guest here, and the server hands it to
  everybody watching — without reading it and without keeping it.

  Two ways in, decided at the join:

    * **the host** of the game being played, with the session's P2P join token
      — the only one whose frames are relayed;
    * **anybody else**, with no token at all — somebody watching, a visitor
      without an account included: watching asks nothing of anyone.

  Both only for a session whose matches may be watched (`Lobby.watchable?/1`):
  a seat offered in the open. A session one person invited another to is not
  relayed, whoever asks.

  What a host may send is bounded: frames of at most 4096 bytes, at most 30
  a second. The thinned stream is about fifteen; past the bound a frame
  is dropped, never queued.
  """

  use Phoenix.Channel, log_join: :debug

  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.JoinToken
  alias RetroHexChat.Topics

  @pubsub RetroHexChat.PubSub
  @max_frame_bytes 4096
  @max_frames_per_second 30

  @impl true
  def join("spectate:" <> token, params, socket) do
    with {:ok, session} <- Lobby.get_session(token),
         true <- Lobby.watchable?(session) || {:error, :not_watchable} do
      join_as(role(params, token), token, socket)
    else
      {:error, :not_watchable} -> {:error, %{reason: "not_watchable"}}
      {:error, _missing} -> {:error, %{reason: "not_found"}}
    end
  end

  defp role(%{"join_token" => join_token}, token) when is_binary(join_token) do
    with {:ok, %{session_token: ^token, user_id: user_id}} <- JoinToken.verify(join_token),
         true <- Lobby.game_host?(token, user_id) do
      :host
    else
      _not_the_host -> :refused
    end
  end

  defp role(_params, _token), do: :watcher

  defp join_as(:refused, _token, _socket), do: {:error, %{reason: "not_host"}}

  defp join_as(:host, token, socket) do
    {:ok, socket |> assign(:token, token) |> assign(:role, :host) |> assign(:window, {0, 0})}
  end

  defp join_as(:watcher, token, socket) do
    Phoenix.PubSub.subscribe(@pubsub, Topics.lobby_watch(token))
    Phoenix.PubSub.subscribe(@pubsub, Topics.lobby_frames(token))
    {:ok, socket |> assign(:token, token) |> assign(:role, :watcher)}
  end

  @impl true
  def handle_in("frame", {:binary, frame}, %{assigns: %{role: :host}} = socket)
      when byte_size(frame) in 1..@max_frame_bytes do
    {allowed?, socket} = within_rate(socket)

    if allowed?,
      do:
        Phoenix.PubSub.broadcast(
          @pubsub,
          Topics.lobby_frames(socket.assigns.token),
          {:watch_frame, frame}
        )

    {:noreply, socket}
  end

  # Too large, not binary, or not the host's to send: dropped without a word,
  # as an over-rate frame is.
  def handle_in("frame", _payload, socket), do: {:noreply, socket}

  # A fixed one-second window per host socket: enough to bound what one page
  # can make the server relay, without a table of its own.
  defp within_rate(%{assigns: %{window: {second, count}}} = socket) do
    now = System.monotonic_time(:second)

    cond do
      now != second -> {true, assign(socket, :window, {now, 1})}
      count < @max_frames_per_second -> {true, assign(socket, :window, {second, count + 1})}
      true -> {false, socket}
    end
  end

  @impl true
  def handle_info({:watch_frame, frame}, socket) do
    push(socket, "frame", {:binary, frame})
    {:noreply, socket}
  end

  def handle_info({:watch_game, payload}, socket) do
    push(socket, "game", Map.take(payload, [:status, :game_id]))
    {:noreply, socket}
  end
end

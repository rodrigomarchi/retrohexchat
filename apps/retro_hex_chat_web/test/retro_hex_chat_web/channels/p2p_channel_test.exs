defmodule RetroHexChatWeb.P2PChannelTest do
  @moduledoc """
  The P2P signaling wire, now that it is a channel rather than the LiveView's
  socket.

  Every assertion here is a bug already paid for somewhere in this product: a
  token spent on the wrong door, an SDP big enough to be a denial of service, a
  candidate that is not one — and `candidate: ""`, which looks malformed and is
  not: it is Firefox saying "no more candidates", and refusing it costs 13.2
  seconds of connection time against 2.1.
  """
  use RetroHexChatWeb.ChannelCase, async: false

  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.JoinToken
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.RegisteredNick
  alias RetroHexChat.VirtualSpace.ChannelJoinToken
  alias RetroHexChatWeb.UserSocket

  @moduletag :integration
  @channel_timeout 1_000

  defp uid, do: System.unique_integer([:positive])

  defp registered(prefix) do
    nickname = "#{prefix}#{uid()}" |> String.slice(0, 16)

    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp session_between(creator, peer) do
    {:ok, %{session: session, token: token}} = Lobby.create_session(creator.id, peer.id)

    on_exit(fn -> Lobby.close_session(token, creator.id, "test_cleanup") end)

    %{session: session, token: token}
  end

  defp join_as(token, nick) do
    {:ok, socket} = connect(UserSocket, %{})

    subscribe_and_join(socket, "p2p:#{token}", %{
      "join_token" => JoinToken.sign(token, nick.id, nick.nickname)
    })
  end

  describe "join" do
    test "refuses a browser with no token" do
      {:ok, socket} = connect(UserSocket, %{})

      assert {:error, %{reason: "invalid_token"}} =
               subscribe_and_join(socket, "p2p:whatever", %{})
    end

    test "refuses a token minted for another session" do
      creator = registered("cre")
      peer = registered("peer")
      %{token: token} = session_between(creator, peer)
      {:ok, socket} = connect(UserSocket, %{})

      assert {:error, %{reason: "invalid_token"}} =
               subscribe_and_join(socket, "p2p:#{token}", %{
                 "join_token" =>
                   JoinToken.sign("some-other-session", creator.id, creator.nickname)
               })
    end

    # The salt is the whole reason `SignedToken` takes one: a token minted for a
    # space is not currency at a P2P door, even for the same person.
    test "refuses a token minted for another kind of door" do
      creator = registered("cre")
      peer = registered("peer")
      %{token: token} = session_between(creator, peer)
      {:ok, socket} = connect(UserSocket, %{})

      assert {:error, %{reason: "invalid_token"}} =
               subscribe_and_join(socket, "p2p:#{token}", %{
                 "join_token" => ChannelJoinToken.sign("#somewhere", creator.id, creator.nickname)
               })
    end

    test "refuses somebody who is not in the session" do
      creator = registered("cre")
      peer = registered("peer")
      stranger = registered("str")
      %{token: token} = session_between(creator, peer)

      assert {:error, %{reason: "not_allowed"}} = join_as(token, stranger)
    end

    test "refuses a session that is over" do
      creator = registered("cre")
      peer = registered("peer")
      %{token: token} = session_between(creator, peer)
      :ok = Lobby.close_session(token, creator.id, "user_closed")

      assert {:error, %{reason: "not_allowed"}} = join_as(token, creator)
    end

    test "refuses a session that never existed" do
      creator = registered("cre")

      {:ok, socket} = connect(UserSocket, %{})

      assert {:error, %{reason: "not_found"}} =
               subscribe_and_join(socket, "p2p:nosuchsession", %{
                 "join_token" => JoinToken.sign("nosuchsession", creator.id, creator.nickname)
               })
    end

    # Joining is the statement "I am listening and I may have missed
    # something", so the catch-up rides the reply rather than a round trip.
    test "hands back whatever the other side already said" do
      creator = registered("cre")
      peer = registered("peer")
      %{token: token} = session_between(creator, peer)
      :ok = Lobby.join_session(token, peer.id)

      :ok =
        Lobby.record_signaling_event(token, creator.id, "lobby_signal", %{
          type: "offer",
          sdp: "v=0 offer-sdp",
          epoch: 1,
          from: creator.id
        })

      assert {:ok, reply, _socket} = join_as(token, peer)
      assert reply.version == 1

      assert [%{event: "lobby_signal", payload: %{type: "offer", replay: true}}] =
               reply.replay.events
    end
  end

  describe "relaying a signal" do
    setup do
      creator = registered("cre")
      peer = registered("peer")
      %{token: token} = session_between(creator, peer)
      :ok = Lobby.join_session(token, peer.id)

      {:ok, _reply, creator_socket} = join_as(token, creator)
      {:ok, _reply, peer_socket} = join_as(token, peer)

      %{token: token, creator: creator, peer: peer, from: creator_socket, to: peer_socket}
    end

    test "an offer reaches the other side and not the sender", ctx do
      ref = push(ctx.from, "lobby_signal", %{"type" => "offer", "sdp" => "v=0 offer"})
      assert_reply ref, :ok, _payload, @channel_timeout

      assert_push "lobby_signal", %{type: "offer", sdp: "v=0 offer", from: from}, @channel_timeout
      assert from == ctx.creator.id
    end

    # It looks like a malformed candidate and it is a sentence: "there are no
    # more". Only Firefox sends it, which is exactly why it is easy to drop.
    test "an empty candidate is end-of-candidates, not a malformed payload", ctx do
      ref =
        push(ctx.from, "lobby_signal", %{
          "type" => "ice-candidate",
          "candidate" => %{"candidate" => "", "sdpMid" => "0", "sdpMLineIndex" => 0}
        })

      assert_reply ref, :ok, _payload, @channel_timeout
      assert_push "lobby_signal", %{type: "ice-candidate"}, @channel_timeout
    end

    test "an SDP nobody could have produced is refused, and the sender is told", ctx do
      ref =
        push(ctx.from, "lobby_signal", %{
          "type" => "offer",
          "sdp" => String.duplicate("v", 300_000)
        })

      assert_reply ref, :error, %{code: "invalid_signal", phase: "signal"}, @channel_timeout
      assert_push "lobby_signal_rejected", %{code: "invalid_signal"}, @channel_timeout
    end

    test "a signal of no known type is refused", ctx do
      ref = push(ctx.from, "lobby_signal", %{"type" => "whatever"})

      assert_reply ref, :error, %{code: "invalid_signal"}, @channel_timeout
    end

    # The answerer never offers. Asking the initiator to is how it gets one, and
    # it is what makes two simultaneous Retry clicks idempotent.
    test "the answerer's renegotiation request reaches the initiator", ctx do
      ref =
        push(ctx.to, "lobby_renegotiate", %{
          "kinds" => ["audio", "video", "telepathy"],
          "recover" => true,
          "epoch" => 3,
          "reason" => "added tracks"
        })

      assert_reply ref, :ok, _payload, @channel_timeout

      assert_receive %Phoenix.Socket.Message{
                       event: "lobby_renegotiate",
                       payload: %{kinds: kinds, recover: true, epoch: 3}
                     },
                     @channel_timeout

      # Only the two track kinds a browser has; the third is dropped rather
      # than relayed to a peer that would not know what to do with it.
      assert kinds == ["audio", "video"]
    end

    test "the wire carries the replay when the client asks for it", ctx do
      :ok =
        Lobby.record_signaling_event(ctx.token, ctx.creator.id, "lobby_signal", %{
          type: "offer",
          sdp: "v=0 replayed",
          epoch: 2,
          from: ctx.creator.id
        })

      ref =
        push(ctx.to, "lobby_signal_replay_request", %{
          "reason" => "gap",
          "epoch" => "2",
          "attempt" => "1"
        })

      assert_reply ref, :ok, _payload, @channel_timeout

      assert_push "lobby_signal_replay",
                  %{reason: "gap", request_epoch: 2, attempt: 1, events: events},
                  @channel_timeout

      assert [%{event: "lobby_signal", payload: %{type: "offer", replay: true}}] = events
    end
  end

  describe "backpressure" do
    setup do
      previous = Application.get_env(:retro_hex_chat, :signaling_rate_limiter)

      Application.put_env(
        :retro_hex_chat,
        :signaling_rate_limiter,
        RetroHexChatWeb.P2PChannelTest.AlwaysLimited
      )

      on_exit(fn ->
        case previous do
          nil -> Application.delete_env(:retro_hex_chat, :signaling_rate_limiter)
          module -> Application.put_env(:retro_hex_chat, :signaling_rate_limiter, module)
        end
      end)

      creator = registered("cre")
      peer = registered("peer")
      %{token: token} = session_between(creator, peer)
      {:ok, _reply, socket} = join_as(token, creator)

      %{socket: socket}
    end

    # Refusing the payload must not refuse the wire: a channel that died here
    # would take the recovery path with it.
    test "a rate-limited signal is refused and the channel stays up", ctx do
      ref = push(ctx.socket, "lobby_signal", %{"type" => "offer", "sdp" => "v=0 offer"})

      assert_reply ref, :error, %{code: "rate_limited", retry_after_ms: 1_500}, @channel_timeout
      assert_push "lobby_signal_rejected", %{code: "rate_limited"}, @channel_timeout

      ref = push(ctx.socket, "lobby_renegotiate", %{"kinds" => ["audio"]})
      assert_reply ref, :error, %{code: "rate_limited", phase: "renegotiate"}, @channel_timeout
    end
  end

  defmodule AlwaysLimited do
    @moduledoc false
    @behaviour RetroHexChat.P2P.SignalingRateLimit

    @impl true
    def check_signal_rate(_session_token, _user_id), do: {:error, {:rate_limited, 1_500}}
  end
end

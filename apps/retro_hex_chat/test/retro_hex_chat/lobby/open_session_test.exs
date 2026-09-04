defmodule RetroHexChat.Lobby.OpenSessionTest do
  @moduledoc """
  The open lobby: a session with a creator, an empty seat and a deadline.

  The test this file exists for is the concurrent claim. Everything else here
  guards an invariant that used to be a `validate_required` and is now a
  condition in a `WHERE`.
  """
  use RetroHexChat.DataCase, async: false

  alias Ecto.Adapters.SQL
  alias RetroHexChat.Chat.IgnoreList
  alias RetroHexChat.Lobby
  alias RetroHexChat.Lobby.{Policy, Queries, Service}
  alias RetroHexChat.Lobby.Schema.Session
  alias RetroHexChat.P2P.{RateLimiter, RateLimitTable}
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  setup do
    on_exit(fn -> :ok end)
    :ok
  end

  defp nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    RateLimiter.reset(RateLimitTable.table_name(), nick.id)
    nick
  end

  defp open_lobby(creator, opts \\ []) do
    {:ok, %{session: session}} = Service.create_open_session(creator.id, opts)
    session
  end

  describe "the changeset invariant" do
    test "peer_id may be null while the session is open" do
      creator = nick("open_cs1")

      assert {:ok, session} =
               Queries.insert_session(%{
                 token: "open-#{System.unique_integer([:positive])}",
                 creator_id: creator.id,
                 peer_id: nil,
                 status: "open"
               })

      assert session.peer_id == nil
      assert Lobby.open_session?(session)
    end

    test "peer_id is required in every other status" do
      creator = nick("open_cs2")

      assert {:error, changeset} =
               Queries.insert_session(%{
                 token: "open-#{System.unique_integer([:positive])}",
                 creator_id: creator.id,
                 peer_id: nil,
                 status: "pending"
               })

      assert %{peer_id: ["can't be blank"]} = errors_on(changeset)
    end

    # The only way into `pending` is the conditional claim, which writes the
    # peer in the same statement. This is the other half of that: a plain
    # status write cannot walk a peerless session into a status that means
    # "there are two of you".
    test "a peerless session cannot be walked into a paired status" do
      creator = nick("open_cs4")
      {:ok, %{session: session}} = Service.create_open_session(creator.id)

      assert {:error, changeset} = Queries.update_status(session, "pending")
      assert %{peer_id: ["can't be blank"]} = errors_on(changeset)

      # But a terminal one still writes, because a match nobody claimed still
      # has to be closeable.
      assert {:ok, expired} =
               Queries.update_status(session, "expired", %{
                 closed_at: DateTime.utc_now(),
                 closed_reason: "open_lobby_unclaimed"
               })

      assert expired.status == "expired"
    end

    test "open is a status the machine knows, and a terminal one still needs its record" do
      assert "open" in Session.status_values()
      refute Session.terminal?("open")

      changeset = Session.status_changeset(%Session{status: "open"}, %{status: "expired"})

      assert %{closed_at: ["can't be blank"], closed_reason: ["can't be blank"]} =
               errors_on(changeset)
    end
  end

  describe "create_open_session/2" do
    test "creates a peerless lobby with a deadline and no process" do
      creator = nick("open_c1")

      assert {:ok, %{session: session, token: token}} = Service.create_open_session(creator.id)
      assert session.status == "open"
      assert session.peer_id == nil
      assert %DateTime{} = session.expires_at
      assert DateTime.after?(session.expires_at, DateTime.utc_now())

      # A link nobody has followed costs a row, not a GenServer.
      assert {:error, :not_found} = Lobby.session_info(token)
    end

    test "an unregistered creator is refused" do
      assert {:error, _message} = Service.create_open_session(-1)
    end

    test "creating match links is rate limited like any other session" do
      creator = nick("open_c3")
      {max_count, _window} = Application.get_env(:retro_hex_chat, :p2p_session_rate_limit)

      for _ <- 1..max_count do
        assert {:ok, _created} = Service.create_open_session(creator.id)
      end

      assert {:error, message} = Service.create_open_session(creator.id)
      assert message =~ "Too many"
    end
  end

  describe "claim_open_session/2" do
    test "the first claimer takes the seat and the session becomes a pending invite" do
      creator = nick("open_k1")
      claimer = nick("open_k1b")
      session = open_lobby(creator)

      assert {:ok, claimed} = Lobby.claim_open_session(session.token, claimer.id)
      assert claimed.peer_id == claimer.id
      assert claimed.status == "pending"
      assert claimed.expires_at == nil
      assert %DateTime{} = claimed.accepted_at

      # The claim is what starts the session's process.
      assert {:ok, _state} = Lobby.session_info(session.token)
    end

    test "claiming your own match link is refused" do
      creator = nick("open_k2")
      session = open_lobby(creator)

      assert {:error, message} = Lobby.claim_open_session(session.token, creator.id)
      assert message =~ "your own"
      assert Queries.get_session_by_token(session.token).peer_id == nil
    end

    test "a user the creator blocks does not get the seat" do
      creator = nick("open_k3")
      claimer = nick("open_k3b")

      {:ok, list} = IgnoreList.add_entry(IgnoreList.new(), claimer.nickname, :all, nil)
      :ok = IgnoreList.save(creator.nickname, list)

      session = open_lobby(creator)

      assert {:error, _message} = Lobby.claim_open_session(session.token, claimer.id)
      assert Queries.get_session_by_token(session.token).peer_id == nil
    end

    test "an expired match link is not a seat" do
      creator = nick("open_k4")
      claimer = nick("open_k4b")
      session = open_lobby(creator, expires_in_ms: -1_000)

      assert {:error, message} = Lobby.claim_open_session(session.token, claimer.id)
      assert message =~ "expired"
    end

    test "a seat already taken reads as full, and says nothing about who took it" do
      creator = nick("open_k5")
      first = nick("open_k5b")
      second = nick("open_k5c")
      session = open_lobby(creator)

      assert {:ok, _claimed} = Lobby.claim_open_session(session.token, first.id)
      assert {:error, message} = Lobby.claim_open_session(session.token, second.id)
      assert message =~ "full"
      refute message =~ first.nickname
    end

    test "a session already running between the two is not joined twice" do
      creator = nick("open_k6")
      claimer = nick("open_k6b")
      {:ok, _direct} = Lobby.create_session(creator.id, claimer.id)
      session = open_lobby(creator)

      assert {:error, message} = Lobby.claim_open_session(session.token, claimer.id)
      assert message =~ "already open"
    end
  end

  describe "two people follow the same link at the same moment" do
    test "exactly one of two concurrent claims wins" do
      creator = nick("open_r1")
      a = nick("open_r1a")
      b = nick("open_r1b")
      session = open_lobby(creator)

      results = claim_together(session.token, [a.id, b.id])

      assert Enum.count(results, &match?({:ok, _session}, &1)) == 1
      assert Enum.count(results, &match?({:error, _reason}, &1)) == 1

      {:ok, winner} = Enum.find(results, &match?({:ok, _session}, &1))
      reloaded = Queries.get_session_by_token(session.token)
      assert reloaded.peer_id == winner.peer_id
      assert reloaded.peer_id in [a.id, b.id]
      assert reloaded.status == "pending"
    end

    test "exactly one of eight concurrent claims wins" do
      creator = nick("open_r2")
      claimers = for i <- 1..8, do: nick("open_r2c#{i}")
      session = open_lobby(creator)

      results = claim_together(session.token, Enum.map(claimers, & &1.id))

      assert Enum.count(results, &match?({:ok, _session}, &1)) == 1
      assert Queries.get_session_by_token(session.token).status == "pending"
    end

    # The two tests above can only be as decisive as the scheduler lets them
    # be: they prove that a claim race resolves to one winner, not *how*. This
    # one is the deterministic half — the seat is taken by a write whose own
    # WHERE re-states everything the policy just read, so removing the
    # condition cannot pass unnoticed even if no interleaving happens to occur.
    test "the claim is a write conditional on the seat still being empty" do
      {sql, _params} =
        SQL.to_sql(:all, Repo, Queries.claim_query("some-token", 1, DateTime.utc_now()))

      assert sql =~ ~s(."peer_id" IS NULL)
      assert sql =~ ~s(."status" = 'open')
    end
  end

  describe "expire_open_sessions/1" do
    test "closes the links past their deadline and leaves the live ones alone" do
      creator = nick("open_e1")
      dead = open_lobby(creator, expires_in_ms: -1_000)
      alive = open_lobby(creator)

      assert {:ok, summary} = Lobby.expire_open_sessions([])
      assert summary.candidates == 1
      assert summary.expired == 1
      assert summary.skipped == 0
      assert summary.remaining == 0

      closed = Queries.get_session_by_token(dead.token)
      assert closed.status == "expired"
      assert closed.closed_reason == "open_lobby_unclaimed"
      assert %DateTime{} = closed.closed_at

      assert Queries.get_session_by_token(alive.token).status == "open"
    end

    test "a lobby claimed between the listing and the write is skipped, not closed" do
      creator = nick("open_e2")
      claimer = nick("open_e2b")
      session = open_lobby(creator)
      # A cutoff far enough ahead that the sweep would list a lobby that is
      # still perfectly live — which is the only way to claim it in between.
      later = DateTime.add(DateTime.utc_now(), 1, :hour)

      [candidate] = Queries.list_expired_open_sessions(later)
      assert {:ok, _claimed} = Lobby.claim_open_session(session.token, claimer.id)

      assert {:ok, :skipped} = Queries.expire_open_session(candidate, later)
      assert Queries.get_session_by_token(session.token).status == "pending"
    end

    test "an expired match link cannot be claimed after the sweep" do
      creator = nick("open_e3")
      claimer = nick("open_e3b")
      session = open_lobby(creator, expires_in_ms: -1_000)

      assert {:ok, _summary} = Lobby.expire_open_sessions([])
      assert {:error, _message} = Lobby.claim_open_session(session.token, claimer.id)
    end
  end

  describe "null peer_id crossing code that assumed two participants" do
    test "an open lobby is not an active session between anybody" do
      creator = nick("open_n1")
      other = nick("open_n1b")
      open_lobby(creator)

      assert Queries.active_sessions_between(creator.id, other.id) == []
      refute Queries.active_session_exists?(creator.id, other.id)
      assert Lobby.active_session_between_nicks(creator.nickname, other.nickname) == nil
    end

    # The chat re-opens the session you are in by asking for your most recently
    # updated one. A match link you just minted is more recent than the call you
    # are already on, and it is not a session you are *in* — nobody is opposite
    # you. Without this, minting a link is enough to make the chat stop drawing
    # the call it was drawing a second ago.
    test "an unclaimed match link is not the session the chat should re-open" do
      creator = nick("open_n1c")
      peer = nick("open_n1d")

      {:ok, %{session: running}} = Service.create_session(creator.id, peer.id)
      open_lobby(creator, metadata: %{"game_id" => "hex_pong"})

      assert Lobby.active_session_for_user(creator.id).token == running.token
    end

    test "nobody can decline a seat nobody has taken" do
      creator = nick("open_n2")
      other = nick("open_n2b")
      session = open_lobby(creator)

      assert {:error, _message} = Policy.can_decline?(other.id, session)
      assert {:error, _message} = Policy.can_decline?(creator.id, session)
    end

    # P7 wants a room that does not outlive its host. Cancelling an unclaimed
    # match link is the same act as cancelling an invite — the creator has
    # stopped waiting — so the door is the same one.
    test "the creator can cancel an unclaimed match link, and a stranger cannot" do
      creator = nick("open_n2c")
      other = nick("open_n2d")
      session = open_lobby(creator)

      assert {:error, _message} = Policy.can_cancel_invite?(other.id, session)
      assert :ok = Policy.can_cancel_invite?(creator.id, session)
      assert :ok = Lobby.cancel_invite(session.token, creator.id)

      closed = Queries.get_session_by_token(session.token)
      assert closed.status == "closed"
      assert closed.closed_reason == "invite_cancelled"
      assert {:error, _gone} = Lobby.claim_open_session(session.token, other.id)
    end

    test "the creator can close their own match link, and a stranger cannot" do
      creator = nick("open_n3")
      other = nick("open_n3b")
      session = open_lobby(creator)

      assert {:error, _message} = Policy.can_close?(other.id, session)
      assert :ok = Policy.can_close?(creator.id, session)
      assert :ok = Lobby.close_session(session.token, creator.id, "user_closed")
      assert Queries.get_session_by_token(session.token).status == "closed"
    end

    test "a summary of an unclaimed lobby names its creator and nobody else" do
      creator = nick("open_n4")
      session = open_lobby(creator)

      assert {:ok, summary} = Lobby.session_summary(session.token)
      assert summary.created_by == creator.nickname
      assert summary.peer == nil
      refute summary.terminal?
    end
  end

  # Both claims are released by the same barrier, so neither has run its policy
  # read before the other starts. A `sleep` here would be the same test with a
  # guess in it.
  defp claim_together(token, user_ids) do
    parent = self()
    count = length(user_ids)

    tasks =
      for user_id <- user_ids do
        Task.async(fn ->
          send(parent, {:at_barrier, self()})

          receive do
            :go -> Lobby.claim_open_session(token, user_id)
          after
            5_000 -> {:error, :barrier_timeout}
          end
        end)
      end

    waiting = for _ <- 1..count, do: receive(do: ({:at_barrier, pid} -> pid))
    for pid <- waiting, do: send(pid, :go)

    Task.await_many(tasks, 10_000)
  end
end

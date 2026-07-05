defmodule RetroHexChat.VirtualSpace.QueriesTest do
  use RetroHexChat.DataCase, async: true

  import RetroHexChat.Factory

  alias RetroHexChat.VirtualSpace.Queries

  @moduletag :unit

  defp insert_session(attrs \\ %{}) do
    creator = insert(:registered_nick)

    base = %{
      token: "space-#{System.unique_integer([:positive])}",
      channel_name: "#retro",
      creator_id: creator.id,
      creator_nick: creator.nickname,
      title: "Tavern hangout"
    }

    {:ok, session} = Queries.insert_session(Map.merge(base, attrs))
    session
  end

  describe "insert_session/1 and get_session_by_token/1" do
    test "round-trips a session by token" do
      session = insert_session()

      found = Queries.get_session_by_token(session.token)
      assert found.id == session.id
      assert found.status == "pending"
    end

    test "returns nil for an unknown token" do
      assert Queries.get_session_by_token("nope") == nil
    end
  end

  describe "update_status/3" do
    test "transitions status with extra attrs" do
      session = insert_session()
      now = DateTime.utc_now()

      assert {:ok, updated} =
               Queries.update_status(session, "active", %{activated_at: now})

      assert updated.status == "active"
      assert updated.activated_at == now
    end

    test "terminal status requires closed_at and closed_reason" do
      session = insert_session()

      assert {:error, changeset} = Queries.update_status(session, "closed")
      errors = errors_on(changeset)
      assert "can't be blank" in errors.closed_at
      assert "can't be blank" in errors.closed_reason
    end
  end

  describe "list_expired_sessions/1" do
    test "lists non-terminal sessions past their expiry" do
      past = DateTime.add(DateTime.utc_now(), -60, :second)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      overdue = insert_session(%{expires_at: past})
      _alive = insert_session(%{expires_at: future})

      {:ok, closed} =
        insert_session(%{expires_at: past})
        |> Queries.update_status("closed", %{
          closed_at: DateTime.utc_now(),
          closed_reason: "test"
        })

      tokens = Enum.map(Queries.list_expired_sessions(DateTime.utc_now()), & &1.token)

      assert overdue.token in tokens
      refute closed.token in tokens
      assert length(tokens) == 1
    end
  end

  describe "expire_session/1" do
    test "marks the session expired with a reason" do
      session = insert_session()

      assert {:ok, expired} = Queries.expire_session(session)
      assert expired.status == "expired"
      assert expired.closed_reason == "expired"
      assert expired.closed_at
    end
  end
end

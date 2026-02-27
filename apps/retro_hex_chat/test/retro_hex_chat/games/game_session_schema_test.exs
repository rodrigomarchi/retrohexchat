defmodule RetroHexChat.Games.Schema.GameSessionTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Games.Schema.GameSession

  @valid_attrs %{
    token: "abc123def456",
    creator_id: 1,
    peer_id: 2,
    status: "pending"
  }

  describe "changeset/2" do
    test "valid attrs produces valid changeset" do
      changeset = GameSession.changeset(%GameSession{}, @valid_attrs)
      assert changeset.valid?
    end

    test "requires token, creator_id, peer_id" do
      changeset = GameSession.changeset(%GameSession{}, %{})
      assert "can't be blank" in errors_on(changeset).token
      assert "can't be blank" in errors_on(changeset).creator_id
      assert "can't be blank" in errors_on(changeset).peer_id
    end

    test "validates token max length" do
      attrs = Map.put(@valid_attrs, :token, String.duplicate("a", 65))
      changeset = GameSession.changeset(%GameSession{}, attrs)
      assert "should be at most 64 character(s)" in errors_on(changeset).token
    end

    test "validates game_id max length" do
      attrs = Map.put(@valid_attrs, :game_id, String.duplicate("a", 31))
      changeset = GameSession.changeset(%GameSession{}, attrs)
      assert "should be at most 30 character(s)" in errors_on(changeset).game_id
    end

    test "validates status inclusion" do
      attrs = Map.put(@valid_attrs, :status, "invalid")
      changeset = GameSession.changeset(%GameSession{}, attrs)
      assert "is invalid" in errors_on(changeset).status
    end

    test "accepts all valid statuses" do
      for status <- ~w(pending lobby playing finished closed expired) do
        changeset = GameSession.changeset(%GameSession{}, %{@valid_attrs | status: status})
        assert changeset.valid?, "status #{status} should be valid"
      end
    end

    test "accepts game_id" do
      attrs = Map.put(@valid_attrs, :game_id, "hex_pong")
      changeset = GameSession.changeset(%GameSession{}, attrs)
      assert changeset.valid?
    end

    test "game_id is optional" do
      changeset = GameSession.changeset(%GameSession{}, @valid_attrs)
      assert changeset.valid?
      assert is_nil(Ecto.Changeset.get_field(changeset, :game_id))
    end
  end

  describe "status_changeset/2" do
    test "updates status" do
      changeset =
        GameSession.status_changeset(%GameSession{status: "pending"}, %{status: "lobby"})

      assert changeset.valid?
    end

    test "requires closed_at and closed_reason for terminal statuses" do
      for status <- ~w(finished closed expired) do
        changeset = GameSession.status_changeset(%GameSession{}, %{status: status})
        refute changeset.valid?, "#{status} without closed_at/reason should be invalid"
      end
    end

    test "terminal status with required fields is valid" do
      attrs = %{
        status: "finished",
        closed_at: DateTime.utc_now(),
        closed_reason: "game_over"
      }

      changeset = GameSession.status_changeset(%GameSession{}, attrs)
      assert changeset.valid?
    end

    test "can update game_id" do
      changeset =
        GameSession.status_changeset(%GameSession{status: "lobby"}, %{
          status: "lobby",
          game_id: "hex_pong"
        })

      assert changeset.valid?
    end
  end

  describe "status_changeset/2 audit columns" do
    test "accepts lobby_at on lobby transition" do
      now = DateTime.utc_now()
      changeset = GameSession.status_changeset(%GameSession{}, %{status: "lobby", lobby_at: now})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :lobby_at) == now
    end

    test "accepts game_started_at on playing transition" do
      now = DateTime.utc_now()

      changeset =
        GameSession.status_changeset(%GameSession{}, %{status: "playing", game_started_at: now})

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :game_started_at) == now
    end

    test "accepts duration_seconds on finished transition" do
      now = DateTime.utc_now()

      changeset =
        GameSession.status_changeset(%GameSession{}, %{
          status: "finished",
          closed_at: now,
          closed_reason: "game_over",
          duration_seconds: 120
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :duration_seconds) == 120
    end
  end

  describe "terminal?/1" do
    test "finished, closed, expired are terminal" do
      assert GameSession.terminal?("finished")
      assert GameSession.terminal?("closed")
      assert GameSession.terminal?("expired")
    end

    test "pending, lobby, playing are not terminal" do
      refute GameSession.terminal?("pending")
      refute GameSession.terminal?("lobby")
      refute GameSession.terminal?("playing")
    end
  end

  describe "status_values/0" do
    test "returns all valid statuses" do
      values = GameSession.status_values()
      assert "pending" in values
      assert "lobby" in values
      assert "playing" in values
      assert "finished" in values
      assert "closed" in values
      assert "expired" in values
    end
  end
end

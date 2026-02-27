defmodule RetroHexChat.P2P.Schema.SessionTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.P2P.Schema.Session

  @moduletag :unit

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        token: "test-token-abc123",
        creator_id: 1,
        peer_id: 2,
        status: "pending",
        session_type: "generic"
      }

      changeset = Session.changeset(%Session{}, attrs)
      assert changeset.valid?
    end

    test "requires token" do
      attrs = %{creator_id: 1, peer_id: 2, status: "pending", session_type: "generic"}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert %{token: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires creator_id" do
      attrs = %{token: "tok", peer_id: 2, status: "pending", session_type: "generic"}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert %{creator_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires peer_id" do
      attrs = %{token: "tok", creator_id: 1, status: "pending", session_type: "generic"}
      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert %{peer_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status enum" do
      for valid_status <- ~w(pending lobby connecting active closed expired failed) do
        attrs = %{
          token: "tok",
          creator_id: 1,
          peer_id: 2,
          status: valid_status,
          session_type: "generic"
        }

        changeset = Session.changeset(%Session{}, attrs)
        assert changeset.valid?, "Expected #{valid_status} to be valid"
      end

      attrs = %{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "invalid",
        session_type: "generic"
      }

      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert %{status: [_]} = errors_on(changeset)
    end

    test "validates session_type enum" do
      for valid_type <- ~w(generic file_transfer audio_call video_call) do
        attrs = %{
          token: "tok",
          creator_id: 1,
          peer_id: 2,
          status: "pending",
          session_type: valid_type
        }

        changeset = Session.changeset(%Session{}, attrs)
        assert changeset.valid?, "Expected #{valid_type} to be valid"
      end

      attrs = %{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "pending",
        session_type: "invalid"
      }

      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert %{session_type: [_]} = errors_on(changeset)
    end

    test "validates token max length 64" do
      long_token = String.duplicate("a", 65)

      attrs = %{
        token: long_token,
        creator_id: 1,
        peer_id: 2,
        status: "pending",
        session_type: "generic"
      }

      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert %{token: [_]} = errors_on(changeset)
    end

    test "validates closed_reason max length 100" do
      long_reason = String.duplicate("a", 101)

      attrs = %{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "closed",
        session_type: "generic",
        closed_reason: long_reason,
        closed_at: DateTime.utc_now()
      }

      changeset = Session.changeset(%Session{}, attrs)
      refute changeset.valid?
      assert %{closed_reason: [_]} = errors_on(changeset)
    end
  end

  describe "status_changeset/2" do
    test "transitions to terminal state require closed_at and closed_reason" do
      session = %Session{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "pending",
        session_type: "generic"
      }

      for terminal <- ~w(closed expired failed) do
        changeset = Session.status_changeset(session, %{status: terminal})

        refute changeset.valid?,
               "Expected terminal state #{terminal} to require closed_at/closed_reason"

        errors = errors_on(changeset)
        assert Map.has_key?(errors, :closed_at), "Missing closed_at for #{terminal}"
        assert Map.has_key?(errors, :closed_reason), "Missing closed_reason for #{terminal}"
      end
    end

    test "transitions to non-terminal state do not require closed_at/closed_reason" do
      session = %Session{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "pending",
        session_type: "generic"
      }

      for non_terminal <- ~w(lobby connecting active) do
        changeset = Session.status_changeset(session, %{status: non_terminal})

        assert changeset.valid?,
               "Expected non-terminal state #{non_terminal} to be valid without closed_at/closed_reason"
      end
    end

    test "transitions to terminal state with closed_at and closed_reason succeeds" do
      session = %Session{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "lobby",
        session_type: "generic"
      }

      changeset =
        Session.status_changeset(session, %{
          status: "closed",
          closed_at: DateTime.utc_now(),
          closed_reason: "user_closed"
        })

      assert changeset.valid?
    end
  end

  describe "status_changeset/2 audit columns" do
    test "accepts accepted_at on lobby transition" do
      session = %Session{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "pending",
        session_type: "generic"
      }

      now = DateTime.utc_now()
      changeset = Session.status_changeset(session, %{status: "lobby", accepted_at: now})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :accepted_at) == now
    end

    test "accepts connected_at on active transition" do
      session = %Session{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "connecting",
        session_type: "generic"
      }

      now = DateTime.utc_now()
      changeset = Session.status_changeset(session, %{status: "active", connected_at: now})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :connected_at) == now
    end

    test "accepts duration_seconds on terminal transition" do
      session = %Session{
        token: "tok",
        creator_id: 1,
        peer_id: 2,
        status: "active",
        session_type: "generic"
      }

      now = DateTime.utc_now()

      changeset =
        Session.status_changeset(session, %{
          status: "closed",
          closed_at: now,
          closed_reason: "user_closed",
          duration_seconds: 42
        })

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :duration_seconds) == 42
    end
  end

  describe "terminal?/1" do
    test "returns true for terminal statuses" do
      for status <- ~w(closed expired failed) do
        assert Session.terminal?(status), "Expected #{status} to be terminal"
      end
    end

    test "returns false for non-terminal statuses" do
      for status <- ~w(pending lobby connecting active) do
        refute Session.terminal?(status), "Expected #{status} to be non-terminal"
      end
    end
  end
end

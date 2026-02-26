defmodule RetroHexChat.Arcade.SoloSessionTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.Arcade.Schema.SoloSession

  describe "changeset/2" do
    test "valid changeset with required fields" do
      changeset =
        SoloSession.changeset(%SoloSession{}, %{
          token: "test_token_123",
          creator_id: 1,
          status: "pending"
        })

      assert changeset.valid?
    end

    test "invalid without token" do
      changeset =
        SoloSession.changeset(%SoloSession{}, %{
          creator_id: 1,
          status: "pending"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:token]
    end

    test "invalid without creator_id" do
      changeset =
        SoloSession.changeset(%SoloSession{}, %{
          token: "test_token",
          status: "pending"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:creator_id]
    end

    test "validates status inclusion" do
      changeset =
        SoloSession.changeset(%SoloSession{}, %{
          token: "test_token",
          creator_id: 1,
          status: "invalid_status"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:status]
    end

    test "validates token length" do
      changeset =
        SoloSession.changeset(%SoloSession{}, %{
          token: String.duplicate("a", 65),
          creator_id: 1,
          status: "pending"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:token]
    end
  end

  describe "status_changeset/2" do
    test "valid transition to lobby" do
      session = %SoloSession{status: "pending"}

      changeset = SoloSession.status_changeset(session, %{status: "lobby"})
      assert changeset.valid?
    end

    test "terminal status requires closed_at and closed_reason" do
      session = %SoloSession{status: "playing"}

      changeset = SoloSession.status_changeset(session, %{status: "finished"})
      refute changeset.valid?
      assert errors_on(changeset)[:closed_at]
      assert errors_on(changeset)[:closed_reason]
    end

    test "terminal status valid with closed fields" do
      session = %SoloSession{status: "playing"}

      changeset =
        SoloSession.status_changeset(session, %{
          status: "finished",
          closed_at: DateTime.utc_now(),
          closed_reason: "game_over"
        })

      assert changeset.valid?
    end
  end

  describe "terminal?/1" do
    test "finished is terminal" do
      assert SoloSession.terminal?("finished")
    end

    test "closed is terminal" do
      assert SoloSession.terminal?("closed")
    end

    test "expired is terminal" do
      assert SoloSession.terminal?("expired")
    end

    test "pending is not terminal" do
      refute SoloSession.terminal?("pending")
    end

    test "lobby is not terminal" do
      refute SoloSession.terminal?("lobby")
    end

    test "playing is not terminal" do
      refute SoloSession.terminal?("playing")
    end
  end
end

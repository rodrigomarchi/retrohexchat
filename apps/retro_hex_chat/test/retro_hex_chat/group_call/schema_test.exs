defmodule RetroHexChat.GroupCall.SchemaTest do
  use RetroHexChat.DataCase, async: true

  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}

  describe "room changesets" do
    test "accepts required room fields" do
      changeset =
        Room.changeset(%Room{}, %{
          token: "group-call-token",
          channel_name: "#elixir",
          creator_id: 1,
          creator_nick: "Alice",
          status: "pending"
        })

      assert changeset.valid?
    end

    test "validates terminal room lifecycle fields" do
      changeset = Room.status_changeset(%Room{status: "active"}, %{status: "closed"})

      refute changeset.valid?
      assert errors_on(changeset)[:closed_at]
      assert errors_on(changeset)[:closed_reason]
    end

    test "knows terminal room statuses" do
      assert Room.terminal?("closed")
      assert Room.terminal?("expired")
      assert Room.terminal?("failed")
      refute Room.terminal?("active")
    end
  end

  describe "participant changesets" do
    test "normalizes nickname" do
      changeset =
        Participant.changeset(%Participant{}, %{
          room_id: 1,
          registered_nick_id: 2,
          nickname: "Alice",
          channel_role_snapshot: "operator",
          status: "joining"
        })

      assert changeset.valid?
      assert get_change(changeset, :normalized_nickname) == "alice"
    end

    test "validates terminal participant lifecycle fields" do
      changeset =
        Participant.status_changeset(%Participant{status: "connected"}, %{status: "left"})

      refute changeset.valid?
      assert errors_on(changeset)[:left_at]
      assert errors_on(changeset)[:reason]
    end

    test "knows terminal participant statuses" do
      assert Participant.terminal?("left")
      assert Participant.terminal?("kicked")
      assert Participant.terminal?("failed")
      refute Participant.terminal?("disconnected")
    end
  end

  describe "track changesets" do
    test "accepts required track fields" do
      changeset =
        Track.changeset(%Track{}, %{
          room_id: 1,
          participant_id: 2,
          kind: "audio",
          source: "microphone",
          webrtc_track_id: "track-1",
          status: "announced"
        })

      assert changeset.valid?
    end

    test "validates track kind" do
      changeset =
        Track.changeset(%Track{}, %{
          room_id: 1,
          participant_id: 2,
          kind: "data",
          source: "datachannel",
          webrtc_track_id: "track-1",
          status: "announced"
        })

      refute changeset.valid?
      assert errors_on(changeset)[:kind]
    end

    test "validates terminal track lifecycle fields" do
      changeset = Track.status_changeset(%Track{status: "active"}, %{status: "ended"})

      refute changeset.valid?
      assert errors_on(changeset)[:ended_at]
      assert errors_on(changeset)[:ended_reason]
    end
  end
end

defmodule RetroHexChat.GroupCall.QueriesTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.GroupCall.Queries
  alias RetroHexChat.Services.RegisteredNick

  @moduletag :integration

  defp create_registered_nick(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{nickname: nickname, password: "password123"})
      |> Repo.insert()

    nick
  end

  defp create_room(attrs \\ %{}) do
    creator =
      Map.get_lazy(attrs, :creator, fn -> create_registered_nick(unique_nick("creator")) end)

    attrs =
      attrs
      |> Map.drop([:creator])
      |> Map.merge(%{
        token: Map.get(attrs, :token, unique_token("room")),
        channel_name: Map.get(attrs, :channel_name, "#calls"),
        creator_id: creator.id,
        creator_nick: creator.nickname,
        status: Map.get(attrs, :status, "pending")
      })

    {:ok, room} = Queries.insert_room(attrs)
    room
  end

  defp create_participant(room, attrs \\ %{}) do
    nick =
      Map.get_lazy(attrs, :registered_nick, fn ->
        create_registered_nick(unique_nick("member"))
      end)

    attrs =
      attrs
      |> Map.drop([:registered_nick])
      |> Map.merge(%{
        room_id: room.id,
        registered_nick_id: nick.id,
        nickname: Map.get(attrs, :nickname, nick.nickname),
        channel_role_snapshot: Map.get(attrs, :channel_role_snapshot, "regular"),
        status: Map.get(attrs, :status, "joining")
      })

    {:ok, participant} = Queries.insert_participant(attrs)
    participant
  end

  defp create_track(room, participant, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          room_id: room.id,
          participant_id: participant.id,
          kind: "audio",
          source: "microphone",
          webrtc_track_id: unique_token("track"),
          status: "announced"
        },
        attrs
      )

    {:ok, track} = Queries.insert_track(attrs)
    track
  end

  defp unique_token(prefix), do: "#{prefix}-#{System.unique_integer([:positive])}"
  defp unique_nick(prefix), do: "#{prefix}#{System.unique_integer([:positive])}"

  describe "rooms" do
    test "allows only one non-terminal room per channel" do
      creator = create_registered_nick(unique_nick("creator"))
      _room = create_room(%{creator: creator, channel_name: "#one"})

      assert {:error, changeset} =
               Queries.insert_room(%{
                 token: unique_token("room"),
                 channel_name: "#one",
                 creator_id: creator.id,
                 creator_nick: creator.nickname,
                 status: "open"
               })

      assert errors_on(changeset)[:channel_name]
    end

    test "allows a new room after the previous room is terminal" do
      creator = create_registered_nick(unique_nick("creator"))

      _closed =
        create_room(%{
          creator: creator,
          channel_name: "#done",
          status: "closed",
          closed_at: DateTime.utc_now(),
          closed_reason: "ended"
        })

      assert {:ok, room} =
               Queries.insert_room(%{
                 token: unique_token("room"),
                 channel_name: "#done",
                 creator_id: creator.id,
                 creator_nick: creator.nickname,
                 status: "pending"
               })

      assert room.channel_name == "#done"
    end

    test "finds active room by channel and ignores terminal rooms" do
      creator = create_registered_nick(unique_nick("creator"))

      _closed =
        create_room(%{
          creator: creator,
          channel_name: "#lookup",
          status: "closed",
          closed_at: DateTime.utc_now(),
          closed_reason: "ended"
        })

      active = create_room(%{creator: creator, channel_name: "#lookup", status: "active"})

      assert Queries.active_room_exists?("#lookup")
      assert Queries.get_active_room_for_channel("#lookup").id == active.id
      refute Queries.active_room_exists?("#missing")
    end

    test "requires closure fields for terminal status updates" do
      room = create_room(%{status: "active"})

      assert {:error, changeset} = Queries.update_room_status(room, "closed")
      assert errors_on(changeset)[:closed_at]
      assert errors_on(changeset)[:closed_reason]
    end
  end

  describe "participants" do
    test "allows only one non-terminal participant per room and nickname" do
      room = create_room()
      nick = create_registered_nick(unique_nick("member"))
      _participant = create_participant(room, %{registered_nick: nick, nickname: "Alice"})

      assert {:error, changeset} =
               Queries.insert_participant(%{
                 room_id: room.id,
                 registered_nick_id: nick.id,
                 nickname: "ALICE",
                 channel_role_snapshot: "regular",
                 status: "connected"
               })

      assert errors_on(changeset)[:normalized_nickname]
    end

    test "allows rejoin record after the previous participant is terminal" do
      room = create_room()
      nick = create_registered_nick(unique_nick("member"))

      _left =
        create_participant(room, %{
          registered_nick: nick,
          nickname: "Alice",
          status: "left",
          left_at: DateTime.utc_now(),
          reason: "left"
        })

      assert {:ok, participant} =
               Queries.insert_participant(%{
                 room_id: room.id,
                 registered_nick_id: nick.id,
                 nickname: "alice",
                 channel_role_snapshot: "regular",
                 status: "joining"
               })

      assert participant.normalized_nickname == "alice"
    end

    test "lists active participants only" do
      room = create_room()
      active = create_participant(room, %{nickname: "Active"})

      _left =
        create_participant(room, %{
          nickname: "Gone",
          status: "left",
          left_at: DateTime.utc_now(),
          reason: "left"
        })

      assert Enum.map(Queries.list_active_participants(room.id), & &1.id) == [active.id]
      assert Queries.get_active_participant(room.id, "ACTIVE").id == active.id
    end
  end

  describe "tracks" do
    test "allows only one non-terminal track per participant kind and source" do
      room = create_room()
      participant = create_participant(room)
      _track = create_track(room, participant)

      assert {:error, changeset} =
               Queries.insert_track(%{
                 room_id: room.id,
                 participant_id: participant.id,
                 kind: "audio",
                 source: "microphone",
                 webrtc_track_id: unique_token("track"),
                 status: "active"
               })

      assert errors_on(changeset)[:source]
    end

    test "allows a new track after the previous track ended" do
      room = create_room()
      participant = create_participant(room)

      _ended =
        create_track(room, participant, %{
          status: "ended",
          ended_at: DateTime.utc_now(),
          ended_reason: "stopped"
        })

      assert {:ok, track} =
               Queries.insert_track(%{
                 room_id: room.id,
                 participant_id: participant.id,
                 kind: "audio",
                 source: "microphone",
                 webrtc_track_id: unique_token("track"),
                 status: "announced"
               })

      assert track.source == "microphone"
    end

    test "lists active tracks only" do
      room = create_room()
      participant = create_participant(room)
      active = create_track(room, participant)

      _ended =
        create_track(room, participant, %{
          kind: "video",
          source: "camera",
          status: "ended",
          ended_at: DateTime.utc_now(),
          ended_reason: "stopped"
        })

      assert Enum.map(Queries.list_active_tracks(room.id), & &1.id) == [active.id]
      assert Queries.get_track_by_webrtc_id(room.id, active.webrtc_track_id).id == active.id
    end

    test "finds active track by participant kind and source" do
      room = create_room()
      participant = create_participant(room)
      active = create_track(room, participant, %{kind: "video", source: "camera"})

      assert Queries.get_active_track_by_source(room.id, participant.id, "video", "camera").id ==
               active.id

      assert Queries.get_active_track_by_source(room.id, participant.id, "audio", "microphone") ==
               nil
    end
  end
end

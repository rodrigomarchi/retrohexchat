defmodule RetroHexChat.Commands.Handlers.Admin.NukeTest do
  use RetroHexChat.DataCase, async: false

  @moduletag :integration

  import Ecto.Query

  alias RetroHexChat.Accounts.{
    ChatDeviceSession,
    TrustedDevice,
    TrustedDeviceEvent,
    TrustedDeviceNick
  }

  alias RetroHexChat.Admin
  alias RetroHexChat.Admin.{AdminRole, AuditLogs}
  alias RetroHexChat.Arcade.Schema.SoloSession
  alias RetroHexChat.Chat.Message
  alias RetroHexChat.Chat.PrivateMessage
  alias RetroHexChat.Commands.Handlers.Admin.Nuke
  alias RetroHexChat.GroupCall.Schema.{Participant, Room, Track}
  alias RetroHexChat.Jobs.RSSPollWorker
  alias RetroHexChat.Lobby.Schema.Session, as: LobbySession
  alias RetroHexChat.Presence.Tracker
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.{NickServ, Queries, RegisteredNick}

  @admin_context %{
    nickname: "NukeAdmin",
    active_channel: "#lobby",
    channels: ["#lobby"],
    identified: true,
    operator_in: [],
    half_operator_in: [],
    is_admin: true,
    is_server_operator: false
  }

  defp seed_data do
    nick = insert_registered_nick!("NukeTestU")
    peer = insert_registered_nick!("NukePeerU")
    now = DateTime.utc_now()

    {:ok, _msg} =
      %Message{}
      |> Message.changeset(%{
        channel_name: "#nuketest",
        author_nickname: nick.nickname,
        content: "hello world"
      })
      |> Repo.insert()

    {:ok, _pm} =
      %PrivateMessage{}
      |> PrivateMessage.changeset(%{
        sender_nickname: nick.nickname,
        recipient_nickname: "NukeAdmin",
        content: "private hello"
      })
      |> Repo.insert()

    {:ok, _lobby} =
      %LobbySession{}
      |> LobbySession.changeset(%{
        token: "nuke-lobby-token",
        creator_id: nick.id,
        peer_id: peer.id,
        status: "pending",
        metadata: %{}
      })
      |> Repo.insert()

    {:ok, _solo} =
      %SoloSession{}
      |> SoloSession.changeset(%{
        token: "nuke-solo-token",
        creator_id: nick.id,
        status: "pending",
        game_id: "pong",
        metadata: %{}
      })
      |> Repo.insert()

    Repo.insert_all("game_sessions", [
      %{
        token: "nuke-game-token",
        creator_id: nick.id,
        peer_id: peer.id,
        status: "pending",
        game_id: "pong",
        metadata: %{},
        inserted_at: now,
        updated_at: now
      }
    ])

    {:ok, room} =
      %Room{}
      |> Room.changeset(%{
        token: "nuke-group-call-token",
        channel_name: "#nuketest",
        creator_id: nick.id,
        creator_nick: nick.nickname,
        status: "open",
        max_participants: 10,
        media_policy: %{},
        codec_policy: %{},
        ice_policy: %{},
        metadata: %{}
      })
      |> Repo.insert()

    {:ok, participant} =
      %Participant{}
      |> Participant.changeset(%{
        room_id: room.id,
        registered_nick_id: nick.id,
        nickname: nick.nickname,
        channel_role_snapshot: "regular",
        status: "connected",
        media_state: %{},
        client_info: %{}
      })
      |> Repo.insert()

    {:ok, _track} =
      %Track{}
      |> Track.changeset(%{
        room_id: room.id,
        participant_id: participant.id,
        kind: "audio",
        source: "mic",
        webrtc_track_id: "nuke-track",
        status: "active",
        metadata: %{}
      })
      |> Repo.insert()

    {:ok, device} =
      %TrustedDevice{}
      |> TrustedDevice.changeset(%{
        selector: "nuke-selector",
        token_hash: "nuke-token-hash",
        first_seen_at: now,
        last_seen_at: now,
        expires_at: DateTime.add(now, 3600, :second)
      })
      |> Repo.insert()

    {:ok, _device_nick} =
      %TrustedDeviceNick{}
      |> TrustedDeviceNick.changeset(%{
        trusted_device_id: device.id,
        registered_nick_id: nick.id,
        granted_at: now
      })
      |> Repo.insert()

    {:ok, _device_event} =
      %TrustedDeviceEvent{}
      |> TrustedDeviceEvent.changeset(%{
        trusted_device_id: device.id,
        registered_nick_id: nick.id,
        actor_nickname: nick.nickname,
        action: "nuke_test",
        details: %{},
        inserted_at: now
      })
      |> Repo.insert()

    {:ok, _device_session} =
      %ChatDeviceSession{}
      |> ChatDeviceSession.changeset(%{
        session_ref: "nuke-session-ref",
        trusted_device_id: device.id,
        registered_nick_id: nick.id,
        nickname: nick.nickname,
        client_info: %{},
        connected_at: now,
        last_seen_at: now
      })
      |> Repo.insert()

    {:ok, _role} =
      %AdminRole{}
      |> AdminRole.changeset(%{
        nickname: "NukeAdmin",
        role: "admin",
        granted_by: "root"
      })
      |> Repo.insert()

    nick
  end

  defp insert_registered_nick!(nickname) do
    {:ok, nick} =
      %RegisteredNick{}
      |> RegisteredNick.registration_changeset(%{
        nickname: nickname,
        password: "password123"
      })
      |> Repo.insert()

    nick
  end

  defp table_count(table_name) do
    Repo.aggregate(from(_ in table_name), :count)
  end

  describe "preview mode" do
    test "returns record counts without deleting" do
      seed_data()

      assert {:ok, :system, %{content: text}} = Nuke.execute([], @admin_context)
      assert text =~ "NUKE PREVIEW"
      assert text =~ "messages:"
      assert text =~ "registered_nicks:"
      assert text =~ "--confirm"

      # Data should still exist
      assert Repo.aggregate(Message, :count) > 0
      assert Repo.aggregate(RegisteredNick, :count) > 0
    end

    test "shows clean message when nothing to delete" do
      assert {:ok, :system, %{content: text}} = Nuke.execute([], @admin_context)
      assert text =~ "Nothing to delete"
    end
  end

  describe "execute mode" do
    test "deletes all data with --confirm" do
      seed_data()

      assert {:ok, :system, %{content: text}} = Nuke.execute(["--confirm"], @admin_context)
      assert text =~ "SYSTEM NUKED"
      assert text =~ "deleted"

      # Verify data is gone
      assert Repo.aggregate(Message, :count) == 0
      assert Repo.aggregate(PrivateMessage, :count) == 0
      assert Repo.aggregate(RegisteredNick, :count) == 0
      assert Repo.aggregate(LobbySession, :count) == 0
      assert Repo.aggregate(SoloSession, :count) == 0
      assert table_count("game_sessions") == 0
      assert Repo.aggregate(Room, :count) == 0
      assert Repo.aggregate(Participant, :count) == 0
      assert Repo.aggregate(Track, :count) == 0
      assert Repo.aggregate(ChatDeviceSession, :count) == 0
      assert Repo.aggregate(TrustedDeviceEvent, :count) == 0
      assert Repo.aggregate(TrustedDeviceNick, :count) == 0
      assert Repo.aggregate(TrustedDevice, :count) == 0
    end

    test "preserves admin_roles" do
      seed_data()

      Nuke.execute(["--confirm"], @admin_context)

      assert Repo.aggregate(AdminRole, :count) > 0
    end

    test "preserves audit_logs" do
      seed_data()
      AuditLogs.log("NukeAdmin", "test.action")
      before_count = Repo.aggregate(RetroHexChat.Admin.AuditLog, :count)

      Nuke.execute(["--confirm"], @admin_context)

      # Audit log count should be >= before (nuke itself adds a log entry)
      assert Repo.aggregate(RetroHexChat.Admin.AuditLog, :count) >= before_count
    end

    test "force-disconnects online users, active device sessions, and requesting admin" do
      seed_data()
      victim = "NukeOnline#{System.unique_integer([:positive])}"

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:NukeAdmin")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "user:#{victim}")
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "chat_device_session:nuke-session-ref")

      {:ok, _ref} = Tracker.track_user("presence:global", victim)

      on_exit(fn ->
        Tracker.untrack_user("presence:global", victim)
      end)

      assert {:ok, _summary} = Admin.nuke_system("NukeAdmin")

      assert_receive {:force_disconnect,
                      %{
                        nickname: "NukeAdmin",
                        system_nuke: true,
                        skip_whowas: true,
                        reason: admin_reason
                      }}

      assert admin_reason =~ "System reset"

      assert_receive {:force_disconnect,
                      %{
                        nickname: ^victim,
                        system_nuke: true,
                        skip_whowas: true
                      }}

      assert_receive {:force_disconnect,
                      %{
                        session_ref: "nuke-session-ref",
                        system_nuke: true,
                        skip_whowas: true
                      }}
    end

    test "broadcasts a global force-disconnect for users connected during the nuke" do
      seed_data()
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "server:settings")

      assert {:ok, _summary} = Admin.nuke_system("NukeAdmin")

      assert_receive {:system_nuked,
                      %{
                        force_disconnect: true,
                        system_nuke: true,
                        skip_whowas: true,
                        reason: reason
                      }}

      assert reason =~ "NukeAdmin"
    end

    test "clears NickServ identified runtime state" do
      nick = insert_registered_nick!("NukeIdentified")
      NickServ.restore_identified(nick.nickname)

      assert NickServ.identified?(nick.nickname)
      assert {:ok, _summary} = Admin.nuke_system("NukeAdmin")
      refute NickServ.identified?(nick.nickname)
    end

    test "reopens registration to avoid locking out admins after the wipe" do
      assert {:ok, _setting} = Queries.upsert_setting("registration", "closed", "NukeAdmin")
      assert Queries.get_setting("registration") == "closed"

      assert {:ok, _summary} = Admin.nuke_system("NukeAdmin")
      assert Queries.get_setting("registration") == "open"
    end

    test "deletes queued background jobs" do
      assert {:ok, _job} =
               %{bot_id: 123, feed_id: "f1"}
               |> RSSPollWorker.new(schedule_in: 60)
               |> Oban.insert()

      assert Repo.aggregate(Oban.Job, :count) == 1

      assert {:ok, _summary} = Admin.nuke_system("NukeAdmin")
      assert Repo.aggregate(Oban.Job, :count) == 0
    end
  end

  describe "error handling" do
    test "returns usage error for invalid args" do
      assert {:error, msg} = Nuke.execute(["--invalid"], @admin_context)
      assert msg =~ "Usage:"
    end
  end

  describe "Admin facade" do
    test "nuke_preview returns counts" do
      seed_data()

      {:ok, counts} = Admin.nuke_preview("NukeAdmin")
      assert is_list(counts)
      assert Enum.any?(counts, fn {name, count} -> name == "messages" and count > 0 end)
      assert Enum.any?(counts, fn {name, count} -> name == "registered_nicks" and count > 0 end)
      assert Enum.any?(counts, fn {name, count} -> name == "trusted_devices" and count > 0 end)
      assert Enum.any?(counts, fn {name, count} -> name == "group_call_rooms" and count > 0 end)
      assert Enum.any?(counts, fn {name, count} -> name == "game_sessions" and count > 0 end)
    end

    test "nuke_system returns deleted counts" do
      seed_data()

      {:ok, summary} = Admin.nuke_system("NukeAdmin")
      assert is_list(summary)

      messages_deleted = Enum.find_value(summary, fn {n, c} -> if n == "messages", do: c end)

      trusted_devices_deleted =
        Enum.find_value(summary, fn {n, c} -> if n == "trusted_devices", do: c end)

      assert messages_deleted > 0
      assert trusted_devices_deleted > 0
    end
  end
end

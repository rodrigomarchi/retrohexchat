defmodule RetroHexChat.Accounts.TrustedDevicesTest do
  use RetroHexChat.DataCase, async: false

  import Ecto.Query

  alias RetroHexChat.Accounts.ChatDeviceSession
  alias RetroHexChat.Accounts.TrustedDevice
  alias RetroHexChat.Accounts.TrustedDeviceEvent
  alias RetroHexChat.Accounts.TrustedDeviceNick
  alias RetroHexChat.Accounts.TrustedDevices
  alias RetroHexChat.Repo
  alias RetroHexChat.Services.Queries

  describe "remember_nick/3 and authorize_cookie/2" do
    test "creates a trusted terminal and authorizes the remembered nick" do
      nick = nick("Trust")
      {:ok, _registered} = Queries.insert_registered_nick(nick, "secret123")

      assert {:ok, %{device: device, cookie_value: cookie, max_age: max_age}} =
               TrustedDevices.remember_nick(nil, nick,
                 client_info: %{browser: "Firefox 140", os: "macOS 15", screen: "1440x900"},
                 label: "Work laptop",
                 actor_nickname: nick
               )

      assert max_age == TrustedDevices.cookie_max_age()
      assert {:ok, verified} = TrustedDevices.verify_cookie(cookie)
      assert verified.id == device.id

      assert [%{nickname: ^nick, label: "Work laptop"} = remembered] =
               TrustedDevices.remembered_nicks(device.id)

      assert remembered.browser == "Firefox 140"
      assert remembered.os == "macOS 15"
      assert remembered.screen == "1440x900"
      assert remembered.device_id == device.id
      assert remembered.granted_at
      assert remembered.last_used_at
      assert remembered.auto_login == false

      assert {:ok, %{device: authorized}} = TrustedDevices.authorize_cookie(cookie, nick)
      assert authorized.id == device.id
    end

    test "one trusted terminal can remember multiple registered nicks" do
      first = nick("One")
      second = nick("Two")
      {:ok, _} = Queries.insert_registered_nick(first, "secret123")
      {:ok, _} = Queries.insert_registered_nick(second, "secret123")

      assert {:ok, %{device: device, cookie_value: cookie}} =
               TrustedDevices.remember_nick(nil, first, actor_nickname: first)

      assert {:ok, %{device: same_device}} =
               TrustedDevices.remember_nick(cookie, second, actor_nickname: second)

      assert same_device.id == device.id

      remembered =
        device.id
        |> TrustedDevices.remembered_nicks()
        |> Enum.map(& &1.nickname)
        |> Enum.sort()

      assert remembered == Enum.sort([first, second])
      assert {:ok, _} = TrustedDevices.authorize_cookie(cookie, first)
      assert {:ok, _} = TrustedDevices.authorize_cookie(cookie, second)
    end

    test "auto-login is a single remembered nick preference per terminal" do
      first = nick("AutoA")
      second = nick("AutoB")
      {:ok, _} = Queries.insert_registered_nick(first, "secret123")
      {:ok, _} = Queries.insert_registered_nick(second, "secret123")

      assert {:ok, %{device: device, cookie_value: cookie}} =
               TrustedDevices.remember_nick(nil, first, actor_nickname: first)

      assert {:ok, %{device: same_device}} =
               TrustedDevices.remember_nick(cookie, second, actor_nickname: second)

      assert same_device.id == device.id

      assert :ok = TrustedDevices.set_auto_login(device.id, first, true, first)
      assert {:ok, ^first} = TrustedDevices.auto_sign_in(device)

      assert :ok = TrustedDevices.set_auto_login(device.id, second, true, second)
      assert {:ok, ^second} = TrustedDevices.auto_sign_in(device)

      remembered = TrustedDevices.remembered_nicks(device.id)
      assert %{auto_login: false} = Enum.find(remembered, &(&1.nickname == first))
      assert %{auto_login: true} = Enum.find(remembered, &(&1.nickname == second))

      assert :ok = TrustedDevices.set_auto_login(device.id, second, false, second)
      assert {:error, :no_auto_login} = TrustedDevices.auto_sign_in(device)
    end

    test "signing in by itself uses the grant and logs it" do
      nick = nick("AutoUse")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      {:ok, %{device: device}} = TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)
      :ok = TrustedDevices.set_auto_login(device.id, nick, true, nick)

      old = DateTime.add(DateTime.utc_now(), -3600, :second)
      Repo.update_all(TrustedDeviceNick, set: [last_used_at: old])

      assert {:ok, ^nick} = TrustedDevices.auto_sign_in(device)

      assert [%{last_used_at: used}] = TrustedDevices.remembered_nicks(device.id)
      assert DateTime.compare(used, old) == :gt

      assert Repo.exists?(
               from(e in TrustedDeviceEvent,
                 where: e.trusted_device_id == ^device.id and e.action == "device.nick.used"
               )
             )
    end

    test "a revoked grant no longer signs in by itself" do
      nick = nick("AutoRev")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      {:ok, %{device: device}} = TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)
      :ok = TrustedDevices.set_auto_login(device.id, nick, true, nick)

      assert :ok = TrustedDevices.revoke_device_for_nick(nick, device.id, nick)
      assert {:error, :no_auto_login} = TrustedDevices.auto_sign_in(device)
    end
  end

  describe "verify_cookie/1" do
    test "writes the time a device was seen at most every few minutes" do
      nick = nick("Seen")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")

      {:ok, %{device: device, cookie_value: cookie}} =
        TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)

      recent = DateTime.add(DateTime.utc_now(), -60, :second)
      Repo.update_all(TrustedDevice, set: [last_seen_at: recent])
      assert {:ok, _} = TrustedDevices.verify_cookie(cookie)
      assert Repo.get!(TrustedDevice, device.id).last_seen_at == recent

      stale = DateTime.add(DateTime.utc_now(), -600, :second)
      Repo.update_all(TrustedDevice, set: [last_seen_at: stale])
      assert {:ok, _} = TrustedDevices.verify_cookie(cookie)
      assert DateTime.compare(Repo.get!(TrustedDevice, device.id).last_seen_at, stale) == :gt
    end
  end

  describe "device and session management" do
    test "revoking a terminal removes trust and disconnects its active sessions" do
      nick = nick("Revoke")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")

      assert {:ok, %{device: device, cookie_value: cookie}} =
               TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)

      assert {:ok, session} = TrustedDevices.record_session_start(nick, device.id, %{})
      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "chat_device_session:#{session.session_ref}")

      assert :ok = TrustedDevices.revoke_device_for_nick(nick, device.id, nick)

      assert_receive {:force_disconnect, %{reason: reason}}
      assert reason =~ "Trusted Terminals"
      assert {:error, :revoked} = TrustedDevices.authorize_cookie(cookie, nick)

      stopped = Repo.get!(ChatDeviceSession, session.id)
      assert stopped.disconnected_at
      assert stopped.disconnect_reason =~ "device_revoked"
    end

    test "kill_session ends only the selected active session" do
      nick = nick("Kill")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      {:ok, one} = TrustedDevices.record_session_start(nick, nil, %{"browser" => "One"})
      {:ok, two} = TrustedDevices.record_session_start(nick, nil, %{"browser" => "Two"})

      Phoenix.PubSub.subscribe(RetroHexChat.PubSub, "chat_device_session:#{one.session_ref}")

      assert :ok = TrustedDevices.kill_session(nick, one.id, nick)
      assert_receive {:force_disconnect, %{reason: reason}}
      assert reason =~ "Trusted Terminals"

      assert Repo.get!(ChatDeviceSession, one.id).disconnected_at
      refute Repo.get!(ChatDeviceSession, two.id).disconnected_at
    end

    test "list read models include persisted terminal and session metadata" do
      nick = nick("Meta")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      ua_hash = TrustedDevices.hash_fingerprint("test-user-agent")
      ip_hash = TrustedDevices.hash_fingerprint("198.51.100.12")

      {:ok, %{device: device}} =
        TrustedDevices.remember_nick(nil, nick,
          actor_nickname: nick,
          user_agent_hash: ua_hash,
          ip_hash: ip_hash,
          client_info: %{
            browser: "Firefox 152",
            os: "macOS 10.15",
            screen: "1512x982",
            timezone: "America/Sao_Paulo",
            language: "pt-BR",
            color_depth: 24,
            cores: 10,
            touch: false
          }
        )

      assert [device_row] = TrustedDevices.list_devices_for_nick(nick)
      assert device_row.id == device.id
      assert device_row.device_type == "desktop"
      assert device_row.language == "pt-BR"
      assert device_row.color_depth == 24
      assert device_row.cores == 10
      assert device_row.touch == false
      assert device_row.auto_login == false
      assert device_row.user_agent_hash == ua_hash
      assert device_row.last_ip_hash == ip_hash

      {:ok, session} =
        TrustedDevices.record_session_start(nick, device.id, %{
          "browser" => "Chrome 150",
          "os" => "Linux",
          "device_type" => "desktop",
          "language" => "en-US",
          "timezone" => "Etc/UTC",
          "screen" => "1920x1080",
          "color_depth" => 30,
          "cores" => 12,
          "touch" => false
        })

      assert [session_row] = TrustedDevices.list_sessions_for_nick(nick).items
      assert session_row.id == session.id
      assert session_row.browser == "Chrome 150"
      assert session_row.os == "Linux"
      assert session_row.device_type == "desktop"
      assert session_row.language == "en-US"
      assert session_row.color_depth == 30
      assert session_row.cores == 12
      assert session_row.touch == false
    end

    test "expire_devices revokes expired terminals and active grants auditably" do
      nick = nick("Expire")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")

      {:ok, %{device: device}} =
        TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)

      expired_at = DateTime.utc_now() |> DateTime.add(-60, :second)

      device
      |> TrustedDevice.changeset(%{expires_at: expired_at})
      |> Repo.update!()

      assert TrustedDevices.expired_device_count(now: DateTime.utc_now()) == 1

      assert {:ok, summary} = TrustedDevices.expire_devices(now: DateTime.utc_now(), limit: 10)

      assert summary.candidates == 1
      assert summary.expired_devices == 1
      assert summary.revoked_grants == 1
      assert summary.skipped == 0

      revoked = Repo.get!(TrustedDevice, device.id)
      assert revoked.revoked_at
      assert revoked.revoked_by_nickname == "system"

      grant = Repo.get_by!(TrustedDeviceNick, trusted_device_id: device.id)
      assert grant.revoked_at
      assert grant.revoked_by_nickname == "system"

      assert Repo.get_by!(TrustedDeviceEvent,
               trusted_device_id: device.id,
               action: "device.expired"
             )
    end

    test "close_stale_sessions marks only sessions without recent heartbeat" do
      nick = nick("Stale")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      {:ok, stale} = TrustedDevices.record_session_start(nick, nil, %{"browser" => "Old"})
      {:ok, fresh} = TrustedDevices.record_session_start(nick, nil, %{"browser" => "Fresh"})

      old = DateTime.utc_now() |> DateTime.add(-600, :second)

      from(session in ChatDeviceSession, where: session.id == ^stale.id)
      |> Repo.update_all(set: [last_seen_at: old])

      assert TrustedDevices.stale_session_count(stale_after_seconds: 300) == 1

      assert {:ok, summary} =
               TrustedDevices.close_stale_sessions(limit: 10, stale_after_seconds: 300)

      assert summary.candidates == 1
      assert summary.closed_sessions == 1

      closed = Repo.get!(ChatDeviceSession, stale.id)
      assert closed.disconnected_at
      assert closed.disconnect_reason == "stale_heartbeat"

      refute Repo.get!(ChatDeviceSession, fresh.id).disconnected_at
    end
  end

  describe "device-scoped preferences" do
    test "stores and reloads settings for a remembered nick on the current terminal" do
      nick = nick("Pref")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      {:ok, %{device: device}} = TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)

      settings = %{
        media: %{audio: false, video: true},
        device_preferences: %{
          audio_input_id: "mic-1",
          video_input_id: "cam-1",
          audio_output_id: "out-1"
        }
      }

      assert :ok =
               TrustedDevices.put_device_preference(
                 device.id,
                 nick,
                 "group_call_prejoin",
                 settings
               )

      assert TrustedDevices.get_device_preference(device.id, nick, "group_call_prejoin") == %{
               "media" => %{"audio" => false, "video" => true},
               "device_preferences" => %{
                 "audio_input_id" => "mic-1",
                 "video_input_id" => "cam-1",
                 "audio_output_id" => "out-1"
               }
             }
    end

    test "updates the same namespace without leaking across nicks or namespaces" do
      first = nick("PrefA")
      second = nick("PrefB")
      {:ok, _} = Queries.insert_registered_nick(first, "secret123")
      {:ok, _} = Queries.insert_registered_nick(second, "secret123")

      {:ok, %{device: device, cookie_value: cookie}} =
        TrustedDevices.remember_nick(nil, first, actor_nickname: first)

      {:ok, %{device: same_device}} =
        TrustedDevices.remember_nick(cookie, second, actor_nickname: second)

      assert same_device.id == device.id

      assert :ok =
               TrustedDevices.put_device_preference(device.id, first, "p2p_setup", %{
                 media: %{audio: true, video: false}
               })

      assert :ok =
               TrustedDevices.put_device_preference(device.id, second, "p2p_setup", %{
                 media: %{audio: false, video: true}
               })

      assert :ok =
               TrustedDevices.put_device_preference(device.id, first, "group_call_prejoin", %{
                 layout: %{mode: "focus"}
               })

      assert :ok =
               TrustedDevices.put_device_preference(device.id, first, "p2p_setup", %{
                 media: %{audio: false, video: false}
               })

      assert TrustedDevices.get_device_preference(device.id, first, "p2p_setup") ==
               %{"media" => %{"audio" => false, "video" => false}}

      assert TrustedDevices.get_device_preference(device.id, second, "p2p_setup") ==
               %{"media" => %{"audio" => false, "video" => true}}

      assert TrustedDevices.get_device_preference(device.id, first, "group_call_prejoin") ==
               %{"layout" => %{"mode" => "focus"}}
    end

    test "does not persist preferences for missing, revoked, expired, or ungranted terminals" do
      nick = nick("PrefStop")
      other = nick("PrefOther")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      {:ok, _} = Queries.insert_registered_nick(other, "secret123")
      {:ok, %{device: device}} = TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)

      assert {:error, :untrusted_device} =
               TrustedDevices.put_device_preference(nil, nick, "p2p_setup", %{})

      assert TrustedDevices.get_device_preference(nil, nick, "p2p_setup") == nil

      assert {:error, :not_found} =
               TrustedDevices.put_device_preference(device.id, other, "p2p_setup", %{})

      assert TrustedDevices.get_device_preference(device.id, other, "p2p_setup") == nil

      assert :ok = TrustedDevices.revoke_device_for_nick(nick, device.id, nick)

      assert {:error, :not_found} =
               TrustedDevices.put_device_preference(device.id, nick, "p2p_setup", %{})

      assert TrustedDevices.get_device_preference(device.id, nick, "p2p_setup") == nil

      fresh = nick("PrefExp")
      {:ok, _} = Queries.insert_registered_nick(fresh, "secret123")

      {:ok, %{device: expired_device}} =
        TrustedDevices.remember_nick(nil, fresh, actor_nickname: fresh)

      expired_device
      |> TrustedDevice.changeset(%{
        expires_at: DateTime.add(DateTime.utc_now(), -1, :second)
      })
      |> Repo.update!()

      assert {:error, :not_found} =
               TrustedDevices.put_device_preference(expired_device.id, fresh, "p2p_setup", %{})

      assert TrustedDevices.get_device_preference(expired_device.id, fresh, "p2p_setup") == nil
    end

    test "rejects invalid namespaces and non-json settings" do
      nick = nick("PrefBad")
      {:ok, _} = Queries.insert_registered_nick(nick, "secret123")
      {:ok, %{device: device}} = TrustedDevices.remember_nick(nil, nick, actor_nickname: nick)

      assert {:error, :invalid_namespace} =
               TrustedDevices.put_device_preference(device.id, nick, "", %{})

      assert {:error, :invalid_namespace} =
               TrustedDevices.put_device_preference(device.id, nick, "UPPERCASE", %{})

      assert {:error, :invalid_settings} =
               TrustedDevices.put_device_preference(device.id, nick, "p2p_setup", %{pid: self()})
    end
  end

  defp nick(prefix), do: "#{prefix}#{System.unique_integer([:positive]) |> rem(100_000)}"
end

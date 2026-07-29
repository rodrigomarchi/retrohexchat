defmodule RetroHexChat.Accounts.TrustedDevicesTest do
  use RetroHexChat.DataCase, async: false

  alias RetroHexChat.Accounts.ChatDeviceSession
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
      assert %{nickname: ^first, auto_login: true} = TrustedDevices.auto_login_nick(device.id)

      assert :ok = TrustedDevices.set_auto_login(device.id, second, true, second)
      assert %{nickname: ^second, auto_login: true} = TrustedDevices.auto_login_nick(device.id)

      remembered = TrustedDevices.remembered_nicks(device.id)
      assert %{auto_login: false} = Enum.find(remembered, &(&1.nickname == first))
      assert %{auto_login: true} = Enum.find(remembered, &(&1.nickname == second))

      assert :ok = TrustedDevices.set_auto_login(device.id, second, false, second)
      assert TrustedDevices.auto_login_nick(device.id) == nil
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
  end

  defp nick(prefix), do: "#{prefix}#{System.unique_integer([:positive]) |> rem(100_000)}"
end

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

      assert [%{nickname: ^nick, label: "Work laptop"}] =
               TrustedDevices.remembered_nicks(device.id)

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
  end

  defp nick(prefix), do: "#{prefix}#{System.unique_integer([:positive]) |> rem(100_000)}"
end

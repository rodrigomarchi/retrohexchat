defmodule RetroHexChat.P2P.P2PTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P
  alias RetroHexChat.P2P.Turn

  @moduletag :unit

  describe "turn_configured?/0" do
    test "returns false when listener_count is 0" do
      original = Application.get_env(:retro_hex_chat, :turn_listener_count)
      Application.put_env(:retro_hex_chat, :turn_listener_count, 0)

      refute P2P.turn_configured?()

      if original, do: Application.put_env(:retro_hex_chat, :turn_listener_count, original)
    end

    test "returns true when listener_count is positive" do
      original = Application.get_env(:retro_hex_chat, :turn_listener_count)
      Application.put_env(:retro_hex_chat, :turn_listener_count, 4)

      assert P2P.turn_configured?()

      if original do
        Application.put_env(:retro_hex_chat, :turn_listener_count, original)
      else
        Application.delete_env(:retro_hex_chat, :turn_listener_count)
      end
    end
  end

  describe "ice_servers/1" do
    setup do
      original_listener_count = Application.get_env(:retro_hex_chat, :turn_listener_count)
      original_relay_ip = Application.get_env(:retro_hex_chat, :turn_relay_ip)
      original_listen_port = Application.get_env(:retro_hex_chat, :turn_listen_port)
      original_locale = Gettext.get_locale(RetroHexChat.Gettext)

      Application.put_env(:retro_hex_chat, :turn_listener_count, 1)
      Application.put_env(:retro_hex_chat, :turn_relay_ip, {203, 0, 113, 42})
      Application.put_env(:retro_hex_chat, :turn_listen_port, 3478)

      on_exit(fn ->
        restore_env(:turn_listener_count, original_listener_count)
        restore_env(:turn_relay_ip, original_relay_ip)
        restore_env(:turn_listen_port, original_listen_port)
        Gettext.put_locale(RetroHexChat.Gettext, original_locale)
      end)

      :ok
    end

    test "returns credentials with correct TTL from config" do
      config = Turn.Config.from_application_env()
      expected_ttl = config.credentials_lifetime

      # Verify config is 3600 (1 hour) as set in config.exs
      assert expected_ttl == 3_600

      servers = P2P.ice_servers("test-user-42")
      assert [%{urls: [_url], username: username, credential: cred}] = servers

      # Username format: "expiry_timestamp:user_id"
      [timestamp_str, user_id] = String.split(username, ":", parts: 2)
      assert user_id == "test-user-42"

      # Expiry should be roughly now + TTL
      {timestamp, _} = Integer.parse(timestamp_str)
      now = System.os_time(:second)
      assert_in_delta timestamp, now + expected_ttl, 5

      # Credential is base64-encoded HMAC
      assert is_binary(cred)
      assert byte_size(cred) > 0
    end

    test "never exposes shared secret in returned payload" do
      servers = P2P.ice_servers("test-user-1")
      server = hd(servers)

      # Only urls, username, credential keys
      assert Map.keys(server) |> Enum.sort() == [:credential, :urls, :username]
    end

    test "returns protocol URLs that are not localized" do
      Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")

      assert [%{urls: ["turn:203.0.113.42:3478?transport=udp"]}] =
               P2P.ice_servers("test-user-pt-br")
    end

    test "returns STUN URL that is not localized when TURN is disabled" do
      Gettext.put_locale(RetroHexChat.Gettext, "pt_BR")
      Application.put_env(:retro_hex_chat, :turn_listener_count, 0)

      assert [%{urls: ["stun:stun.l.google.com:19302"]}] = P2P.ice_servers("test-user-pt-br")
    end
  end

  describe "validate_signal/1" do
    test "accepts valid offer" do
      signal = %{"type" => "offer", "sdp" => "v=0\r\n..."}
      assert {:ok, validated} = P2P.validate_signal(signal)
      assert validated.type == "offer"
      assert validated.sdp == "v=0\r\n..."
    end

    test "accepts valid answer" do
      signal = %{"type" => "answer", "sdp" => "v=0\r\n..."}
      assert {:ok, validated} = P2P.validate_signal(signal)
      assert validated.type == "answer"
    end

    test "accepts valid ice-candidate" do
      candidate = %{"candidate" => "candidate:1 1 udp ...", "sdpMid" => "0"}
      signal = %{"type" => "ice-candidate", "candidate" => candidate}
      assert {:ok, validated} = P2P.validate_signal(signal)
      assert validated.type == "ice-candidate"
      assert validated.candidate == candidate
    end

    test "rejects invalid type" do
      signal = %{"type" => "invalid", "sdp" => "..."}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects offer without sdp" do
      signal = %{"type" => "offer"}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects answer without sdp" do
      signal = %{"type" => "answer"}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects ice-candidate without candidate" do
      signal = %{"type" => "ice-candidate"}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects missing type" do
      signal = %{"sdp" => "..."}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end

    test "rejects empty sdp" do
      signal = %{"type" => "offer", "sdp" => ""}
      assert {:error, :invalid_signal} = P2P.validate_signal(signal)
    end
  end

  defp restore_env(key, nil), do: Application.delete_env(:retro_hex_chat, key)
  defp restore_env(key, value), do: Application.put_env(:retro_hex_chat, key, value)
end

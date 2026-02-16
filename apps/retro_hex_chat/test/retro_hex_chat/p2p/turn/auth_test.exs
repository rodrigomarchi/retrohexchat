defmodule RetroHexChat.P2P.Turn.AuthTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.Turn.{Auth, Config}

  setup do
    config = Config.from_application_env()
    %{config: config}
  end

  @moduletag :unit

  describe "generate_credentials/2" do
    test "returns valid credential structure", %{config: config} do
      result = Auth.generate_credentials("user123", config)

      assert is_map(result)
      assert is_binary(result.username)
      assert is_binary(result.password)
      assert is_integer(result.ttl)
      assert result.ttl == config.credentials_lifetime
    end

    test "username contains timestamp and user_id", %{config: config} do
      result = Auth.generate_credentials("user42", config)

      assert result.username =~ ~r/^\d+:user42$/
    end

    test "password is base64-encoded HMAC", %{config: config} do
      result = Auth.generate_credentials("user1", config)

      # Password should be valid base64
      assert {:ok, _} = Base.decode64(result.password)
    end

    test "credentials with different user_ids produce different passwords", %{config: config} do
      cred1 = Auth.generate_credentials("user1", config)
      cred2 = Auth.generate_credentials("user2", config)

      assert cred1.password != cred2.password
    end
  end
end

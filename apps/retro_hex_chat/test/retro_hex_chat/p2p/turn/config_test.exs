defmodule RetroHexChat.P2P.Turn.ConfigTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.Turn.Config

  @moduletag :unit

  describe "from_application_env/0" do
    test "builds config from application environment" do
      config = Config.from_application_env()

      assert config.realm == "retro-hex-chat"
      assert config.credentials_lifetime == 3_600
      assert config.nonce_lifetime == 3_600_000_000_000
      assert config.default_allocation_lifetime == 600
      assert config.max_allocation_lifetime == 3_600
      assert config.permission_lifetime == 300
      assert config.channel_lifetime == 600
    end
  end

  describe "guess_external_ip/0" do
    test "returns a valid IPv4 tuple" do
      ip = Config.guess_external_ip()
      assert is_tuple(ip)
      assert tuple_size(ip) == 4
    end
  end
end

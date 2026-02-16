defmodule RetroHexChat.P2P.Turn.ConfigTest do
  use ExUnit.Case, async: true

  alias RetroHexChat.P2P.Turn.Config

  @moduletag :unit

  describe "from_application_env/0" do
    test "builds config from application environment" do
      config = Config.from_application_env()

      assert %Config{} = config
      assert config.realm == "retro-hex-chat"
      assert config.credentials_lifetime == 86_400
      assert config.nonce_lifetime == 3_600_000_000_000
      assert config.default_allocation_lifetime == 600
      assert config.max_allocation_lifetime == 3_600
      assert config.permission_lifetime == 300
      assert config.channel_lifetime == 600
      assert is_binary(config.auth_secret)
      assert is_binary(config.nonce_secret)
      assert is_integer(config.listen_port)
      assert is_tuple(config.listen_ip)
    end
  end

  describe "new/1" do
    test "creates config with valid attrs" do
      attrs = %{
        listen_ip: {127, 0, 0, 1},
        listen_port: 3478,
        relay_ip: {192, 168, 1, 1},
        relay_port_range: {49_152, 65_535},
        listener_count: 2,
        realm: "test-realm",
        auth_secret: "secret",
        nonce_secret: "nonce",
        credentials_lifetime: 3600,
        nonce_lifetime: 1_000_000_000,
        default_allocation_lifetime: 300,
        max_allocation_lifetime: 1800,
        permission_lifetime: 300,
        channel_lifetime: 600
      }

      config = Config.new(attrs)
      assert config.realm == "test-realm"
      assert config.listen_port == 3478
      assert config.relay_ip == {192, 168, 1, 1}
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

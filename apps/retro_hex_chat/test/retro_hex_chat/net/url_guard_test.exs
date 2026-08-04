defmodule RetroHexChat.Net.URLGuardTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Net.URLGuard

  describe "check/1" do
    test "accepts public literal HTTP addresses" do
      assert :ok = URLGuard.check("HTTPS://93.184.216.34/feed.xml")
    end

    test "rejects embedded credentials" do
      assert {:error, reason} = URLGuard.check("https://user:pass@example.com/feed.xml")
      assert reason =~ "credentials"
    end

    test "rejects special-use IPv4 ranges that are not public targets" do
      for host <- [
            "192.0.2.1",
            "198.18.0.1",
            "198.51.100.1",
            "203.0.113.1",
            "224.0.0.1",
            "240.0.0.1"
          ] do
        assert {:error, reason} = URLGuard.check("http://#{host}/feed.xml")
        assert reason =~ "public", "#{host} should not be fetchable"
      end
    end
  end

  describe "fetch_target/1" do
    test "pins the request URL to a resolved address and keeps the original hostname" do
      assert {:ok, target} = URLGuard.fetch_target("https://93.184.216.34/path?q=1#fragment")

      assert target.url == "https://93.184.216.34/path?q=1"
      assert target.hostname == "93.184.216.34"
      assert target.connect_options[:hostname] == "93.184.216.34"
      refute Map.get(target, :inet6?)
    end
  end

  describe "private?/1" do
    test "covers IPv6 special-use ranges" do
      assert URLGuard.private?({0x0064, 0xFF9B, 0, 0, 0, 0, 0x7F00, 0x0001})
      assert URLGuard.private?({0x0100, 0, 0, 0, 0, 0, 0, 1})
      assert URLGuard.private?({0x2001, 0x0DB8, 0, 0, 0, 0, 0, 1})
      assert URLGuard.private?({0xFF02, 0, 0, 0, 0, 0, 0, 1})
    end
  end
end

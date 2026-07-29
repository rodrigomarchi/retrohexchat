defmodule RetroHexChat.Bots.Capabilities.RSS.UrlGuardTest do
  use ExUnit.Case, async: true

  @moduletag :unit

  alias RetroHexChat.Bots.Capabilities.RSS.UrlGuard

  describe "check/1" do
    test "accepts an ordinary public feed" do
      assert :ok = UrlGuard.check("https://example.com/feed.xml")
    end

    test "refuses anything that is not http or https" do
      assert {:error, msg} = UrlGuard.check("file:///etc/passwd")
      assert msg =~ "http"

      assert {:error, _} = UrlGuard.check("gopher://example.com/feed")
    end

    test "refuses an address with no host" do
      assert {:error, msg} = UrlGuard.check("https:///feed.xml")
      assert msg =~ "host"
    end

    test "refuses loopback, however it is spelled" do
      assert {:error, _} = UrlGuard.check("http://127.0.0.1/feed")
      assert {:error, _} = UrlGuard.check("http://localhost:4000/feed")
      assert {:error, _} = UrlGuard.check("http://[::1]/feed")
    end

    test "refuses the link-local range where metadata services live" do
      assert {:error, msg} = UrlGuard.check("http://169.254.169.254/latest/meta-data/")
      assert msg =~ "public"
    end

    test "refuses private ranges" do
      for host <- ["10.0.0.5", "192.168.1.1", "172.16.0.1", "172.31.255.254"] do
        assert {:error, _} = UrlGuard.check("http://#{host}/feed"), "#{host} should be refused"
      end
    end

    test "allows a public address that merely looks close to a private one" do
      assert :ok = UrlGuard.check("http://172.32.0.1/feed")
      assert :ok = UrlGuard.check("http://11.0.0.1/feed")
    end

    test "reports a name that does not resolve rather than fetching it" do
      assert {:error, msg} = UrlGuard.check("https://nx.invalid/feed.xml")
      assert msg =~ "resolve"
    end
  end

  describe "private?/1" do
    test "sees through a v4-mapped v6 address" do
      # ::ffff:127.0.0.1
      assert UrlGuard.private?({0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001})
      # ::ffff:8.8.8.8
      refute UrlGuard.private?({0, 0, 0, 0, 0, 0xFFFF, 0x0808, 0x0808})
    end

    test "covers unique-local and link-local v6" do
      assert UrlGuard.private?({0xFD00, 0, 0, 0, 0, 0, 0, 1})
      assert UrlGuard.private?({0xFE80, 0, 0, 0, 0, 0, 0, 1})
      refute UrlGuard.private?({0x2001, 0x4860, 0, 0, 0, 0, 0, 0x8888})
    end
  end
end

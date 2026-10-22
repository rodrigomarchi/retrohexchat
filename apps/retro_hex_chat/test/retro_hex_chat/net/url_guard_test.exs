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

  describe "check/1 — what a feed or a pasted link may point at" do
    test "accepts an ordinary public feed" do
      assert :ok = URLGuard.check("https://example.com/feed.xml")
    end

    test "refuses anything that is not http or https" do
      assert {:error, msg} = URLGuard.check("file:///etc/passwd")
      assert msg =~ "http"

      assert {:error, _} = URLGuard.check("gopher://example.com/feed")
    end

    test "refuses an address with no host" do
      assert {:error, msg} = URLGuard.check("https:///feed.xml")
      assert msg =~ "host"
    end

    test "refuses loopback, however it is spelled" do
      assert {:error, _} = URLGuard.check("http://127.0.0.1/feed")
      assert {:error, _} = URLGuard.check("http://localhost:4000/feed")
      assert {:error, _} = URLGuard.check("http://[::1]/feed")
    end

    test "refuses the link-local range where metadata services live" do
      assert {:error, msg} = URLGuard.check("http://169.254.169.254/latest/meta-data/")
      assert msg =~ "public"
    end

    test "refuses private ranges" do
      for host <- ["10.0.0.5", "192.168.1.1", "172.16.0.1", "172.31.255.254"] do
        assert {:error, _} = URLGuard.check("http://#{host}/feed"), "#{host} should be refused"
      end
    end

    test "allows a public address that merely looks close to a private one" do
      assert :ok = URLGuard.check("http://172.32.0.1/feed")
      assert :ok = URLGuard.check("http://11.0.0.1/feed")
    end

    test "reports a name that does not resolve rather than fetching it" do
      assert {:error, msg} = URLGuard.check("https://nx.invalid/feed.xml")
      assert msg =~ "resolve"
    end
  end

  describe "private?/1 — IPv6 spellings" do
    test "sees through a v4-mapped v6 address" do
      # ::ffff:127.0.0.1
      assert URLGuard.private?({0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001})
      # ::ffff:8.8.8.8
      refute URLGuard.private?({0, 0, 0, 0, 0, 0xFFFF, 0x0808, 0x0808})
    end

    test "covers unique-local and link-local v6" do
      assert URLGuard.private?({0xFD00, 0, 0, 0, 0, 0, 0, 1})
      assert URLGuard.private?({0xFE80, 0, 0, 0, 0, 0, 0, 1})
      refute URLGuard.private?({0x2001, 0x4860, 0, 0, 0, 0, 0, 0x8888})
    end
  end
end

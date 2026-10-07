defmodule RetroHexChat.SEO.IndexNowTest do
  @moduledoc """
  The IndexNow request: what is sent, in how many requests, and what each
  answer means.
  """
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.SEO.IndexNow

  @key "0123456789abcdef0123456789abcdef"

  setup do
    previous = Application.get_env(:retro_hex_chat, :index_now)
    Application.put_env(:retro_hex_chat, :index_now, Keyword.put(previous || [], :key, @key))
    Application.put_env(:retro_hex_chat, :index_now_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      Application.put_env(:retro_hex_chat, :index_now, previous)
      Application.delete_env(:retro_hex_chat, :index_now_req_options)
    end)
  end

  describe "payloads/2" do
    test "names the host and the key location from the URLs themselves" do
      assert {:ok, [payload]} =
               IndexNow.payloads(["https://example.app/", "https://example.app/faq"], @key)

      assert payload == %{
               host: "example.app",
               key: @key,
               keyLocation: "https://example.app/indexnow.txt",
               urlList: ["https://example.app/", "https://example.app/faq"]
             }
    end

    test "splits at ten thousand URLs" do
      urls = for n <- 1..10_001, do: "https://example.app/p#{n}"

      assert {:ok, [first, second]} = IndexNow.payloads(urls, @key)
      assert length(first.urlList) == 10_000
      assert second.urlList == ["https://example.app/p10001"]
    end

    test "refuses URLs on more than one host" do
      assert {:error, :mixed_hosts} =
               IndexNow.payloads(["https://example.app/", "https://other.app/"], @key)
    end

    test "nothing to send is no request" do
      assert {:ok, []} = IndexNow.payloads([], @key)
    end
  end

  describe "submit/1" do
    test "posts the payload as JSON and counts what was sent" do
      Req.Test.expect(__MODULE__, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert conn.request_path == "/indexnow"

        assert Jason.decode!(body) == %{
                 "host" => "example.app",
                 "key" => @key,
                 "keyLocation" => "https://example.app/indexnow.txt",
                 "urlList" => ["https://example.app/faq"]
               }

        Plug.Conn.send_resp(conn, 200, "")
      end)

      assert {:ok, %{submitted: 1, batches: 1}} =
               IndexNow.submit(["https://example.app/faq", "https://example.app/faq"])
    end

    test "202 means received, key not yet verified: still a success" do
      Req.Test.stub(__MODULE__, &Plug.Conn.send_resp(&1, 202, ""))

      assert {:ok, %{submitted: 1}} = IndexNow.submit(["https://example.app/"])
    end

    test "a refusal is the status, and the batches after it are not sent" do
      Req.Test.expect(__MODULE__, &Plug.Conn.send_resp(&1, 422, ""))
      urls = for n <- 1..10_001, do: "https://example.app/p#{n}"

      assert {:error, {:http_status, 422}} = IndexNow.submit(urls)
    end

    test "a transport failure is named, not raised" do
      Req.Test.stub(__MODULE__, &Req.Test.transport_error(&1, :econnrefused))

      assert {:error, :fetch_failed} = IndexNow.submit(["https://example.app/"])
    end

    test "a timeout is told apart from other transport failures" do
      Req.Test.stub(__MODULE__, &Req.Test.transport_error(&1, :timeout))

      assert {:error, :timeout} = IndexNow.submit(["https://example.app/"])
    end

    test "an empty list sends nothing" do
      assert {:ok, %{submitted: 0, batches: 0}} = IndexNow.submit([])
    end
  end
end

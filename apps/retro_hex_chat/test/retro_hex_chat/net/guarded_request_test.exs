defmodule RetroHexChat.Net.GuardedRequestTest do
  use ExUnit.Case, async: false

  @moduletag :unit

  alias RetroHexChat.Net.GuardedRequest

  @overrides :guarded_request_test_req_options
  @public "https://93.184.216.34"

  setup {Req.Test, :verify_on_exit!}

  setup do
    Application.put_env(:retro_hex_chat, @overrides, plug: {Req.Test, __MODULE__})
    on_exit(fn -> Application.delete_env(:retro_hex_chat, @overrides) end)
    :ok
  end

  defp get(url, opts \\ []) do
    GuardedRequest.get(url, Keyword.merge([max_body_size: 1_000, overrides: @overrides], opts))
  end

  defp redirect(conn, location) do
    conn |> Plug.Conn.put_resp_header("location", location) |> Plug.Conn.resp(302, "")
  end

  test "returns a non-redirect response with the address it came from" do
    Req.Test.expect(__MODULE__, &Plug.Conn.resp(&1, 404, "missing"))

    assert {:ok, %{status: 404, body: "missing"}, "#{@public}/a"} = get("#{@public}/a")
  end

  test "follows a relative redirect and reports the final address" do
    Req.Test.expect(__MODULE__, &redirect(&1, "/b"))
    Req.Test.expect(__MODULE__, &Plug.Conn.resp(&1, 200, "ok"))

    assert {:ok, %{status: 200, body: "ok"}, "#{@public}/b"} = get("#{@public}/a")
  end

  test "checks every redirect target again" do
    Req.Test.expect(__MODULE__, &redirect(&1, "http://127.0.0.1/admin"))

    assert {:error, {:blocked, _reason}} = get("#{@public}/a")
  end

  test "stops after max_redirects" do
    Req.Test.expect(__MODULE__, 2, &redirect(&1, "/again"))

    assert {:error, :too_many_redirects} = get("#{@public}/a", max_redirects: 1)
  end

  test "a redirect without a location is an error" do
    Req.Test.expect(__MODULE__, &Plug.Conn.resp(&1, 301, ""))

    assert {:error, :redirect_without_location} = get("#{@public}/a")
  end

  test "reads the body only up to the cap" do
    Req.Test.expect(__MODULE__, &Plug.Conn.resp(&1, 200, String.duplicate("x", 5_000)))

    assert {:ok, %{body: body}, _url} = get("#{@public}/big", max_body_size: 100)
    assert byte_size(body) == 100
  end

  test "refuses an address the guard rejects before any request" do
    assert {:error, {:blocked, _reason}} = get("http://localhost/")
  end

  describe "first_header/2" do
    test "reads Req's lower-case keys and a hand-built map's own spelling" do
      assert GuardedRequest.first_header(%{"etag" => ["v1", "v2"]}, "ETag") == "v1"
      assert GuardedRequest.first_header(%{"ETag" => "v1"}, "ETag") == "v1"
      assert GuardedRequest.first_header(%{}, "etag") == nil
    end
  end

  describe "redirect_url/2" do
    test "resolves a location against the current address" do
      assert GuardedRequest.redirect_url("https://a.example/x/y", " ../z ") ==
               "https://a.example/z"

      assert GuardedRequest.redirect_url("https://a.example/", nil) == nil
    end
  end
end

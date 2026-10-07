defmodule RetroHexChatWeb.VersionControllerTest do
  use RetroHexChatWeb.ConnCase, async: false

  @moduletag :unit

  setup do
    previous = System.get_env("APP_VERSION")
    on_exit(fn -> restore("APP_VERSION", previous) end)
  end

  defp restore(name, nil), do: System.delete_env(name)
  defp restore(name, value), do: System.put_env(name, value)

  test "names the release and its commit, uncached", %{conn: conn} do
    System.put_env("APP_VERSION", "0.1.0-5917af959")

    conn = get(conn, "/version")

    assert json_response(conn, 200) == %{"version" => "0.1.0-5917af959", "commit" => "5917af959"}
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end

  test "outside a release there is no commit", %{conn: conn} do
    System.put_env("APP_VERSION", "0.1.0")

    assert json_response(get(conn, "/version"), 200) == %{"version" => "0.1.0", "commit" => nil}
  end

  test "answers under every locale preference, never redirecting", %{conn: conn} do
    conn = conn |> put_req_header("accept-language", "pt-BR") |> get("/version")

    assert conn.status == 200
  end
end

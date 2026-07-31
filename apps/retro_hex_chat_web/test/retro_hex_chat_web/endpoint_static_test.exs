defmodule RetroHexChatWeb.EndpointStaticTest do
  @moduledoc """
  Static asset serving, driven through the endpoint itself.

  `Plug.Static` matches its allow-list against the first path segment, so a list
  naming `favicon.ico` never serves `favicon-<digest>.ico` — the name
  `~p"/favicon.ico"` resolves to once assets are digested. Only a digested build
  shows it, which is why the icon 404'd in production while every test passed.
  """
  use RetroHexChatWeb.ConnCase, async: false

  @moduletag :unit

  defp with_static_file(name, body) do
    path = Path.join(Application.app_dir(:retro_hex_chat_web, "priv/static"), name)
    File.write!(path, body)
    on_exit(fn -> File.rm_rf!(path) end)

    "/" <> name
  end

  test "serves a digested top-level asset", %{conn: conn} do
    url = with_static_file("favicon-endpointstatictest.ico", "icon")

    assert conn |> get(url) |> response(200) == "icon"
  end

  test "serves the undigested favicon", %{conn: conn} do
    assert conn |> get("/favicon.ico") |> response(200)
  end

  test "leaves unrelated top-level files unserved", %{conn: conn} do
    url = with_static_file("endpointstatictest-secrets.env", "nope")

    assert conn |> get(url) |> response(404)
  end
end

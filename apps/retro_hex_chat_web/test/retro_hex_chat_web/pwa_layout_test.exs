defmodule RetroHexChatWeb.PwaLayoutTest do
  @moduledoc """
  The three public-facing layouts declare the web app manifest.

  A manifest reachable at its URL but linked from no page installs nothing —
  the browser only offers to install a page that points at one.
  """
  use RetroHexChatWeb.ConnCase, async: true

  @moduletag :unit

  test "the chat layout links the manifest", %{conn: conn} do
    html = conn |> get(~p"/connect") |> html_response(200)

    assert html =~ ~s(rel="manifest")
    assert html =~ "manifest.webmanifest"
  end

  test "the landing layout links the manifest", %{conn: conn} do
    html = conn |> get(~p"/") |> html_response(200)

    assert html =~ ~s(rel="manifest")
  end

  test "the help layout links the manifest", %{conn: conn} do
    html = conn |> get(~p"/chat/help") |> html_response(200)

    assert html =~ ~s(rel="manifest")
  end

  # An installed window has no browser chrome to colour, so the theme colour is
  # what the OS paints around it.
  test "the chat layout declares a theme colour", %{conn: conn} do
    html = conn |> get(~p"/connect") |> html_response(200)

    assert html =~ ~s(name="theme-color")
  end
end

defmodule RetroHexChatWeb.PayloadBudgetTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChatWeb.PerfBudgets

  @moduletag :integration

  # A page's first paint costs what its HTML costs: bytes over the wire, then
  # a DOM node per element on the main thread. These are the numbers RUM reads
  # back as `element_render_delay`, so they are asserted here rather than
  # discovered after a deploy.

  describe "/connect" do
    setup %{conn: conn}, do: %{html: html_for(conn, ~p"/connect")}

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:connect)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:connect)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "a help topic" do
    setup %{conn: conn}, do: %{html: html_for(conn, ~p"/chat/help")}

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:help)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:help)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "/play" do
    setup %{conn: conn}, do: %{html: html_for(session_conn(conn), ~p"/play")}

    test "stays inside its byte budget", %{html: html} do
      assert byte_size(html) <= PerfBudgets.html_bytes(:play)
    end

    test "stays inside its DOM node budget", %{html: html} do
      assert PerfBudgets.count_elements(html) <= PerfBudgets.dom_nodes(:play)
    end

    test "references the sprite instead of carrying the drawings", %{html: html} do
      assert PerfBudgets.count(html, "<use href=") == PerfBudgets.count(html, "<svg")
    end
  end

  describe "every surface" do
    test "ships no icon art inline", %{conn: conn} do
      for path <- [~p"/connect", ~p"/chat/help"] do
        html = html_for(conn, path)

        # Everything an icon draws with. A diagram may legitimately use these,
        # but no surface here renders one.
        for tag <- ~w(<rect <polygon <ellipse) do
          assert PerfBudgets.count(html, tag) == 0,
                 "#{path} still inlines icon art (#{tag})"
        end
      end
    end
  end

  defp html_for(conn, path), do: conn |> get(path) |> html_response(200)

  # A surface refuses a request with no nickname, so measuring one needs a
  # session the way a visitor would have one.
  defp session_conn(conn) do
    Plug.Test.init_test_session(conn, %{"chat_nickname" => "Budget"})
  end
end

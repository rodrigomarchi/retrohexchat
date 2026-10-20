Code.require_file("ci_test_selection.exs", __DIR__)

ExUnit.start()

defmodule CITestSelectionTest do
  use ExUnit.Case, async: true

  @domain "apps/retro_hex_chat"
  @web "apps/retro_hex_chat_web"

  # Bar calls Foo; PageLive calls Bar and is served at /page/:id.
  @graph %{
    "lib/retro_hex_chat/bar.ex" => %{"lib/retro_hex_chat/foo.ex" => "runtime"},
    "lib/retro_hex_chat_web/live/page_live.ex" => %{"lib/retro_hex_chat/bar.ex" => "runtime"}
  }

  @routes """
    GET   /                  RetroHexChatWeb.HomeLive :index
    GET   /page/:id          RetroHexChatWeb.PageLive :show
  """

  setup do
    root = Path.join(System.tmp_dir!(), "ci-selection-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(root) end)

    write(root, "#{@domain}/lib/retro_hex_chat/foo.ex", "defmodule RetroHexChat.Foo do\nend\n")
    write(root, "#{@domain}/lib/retro_hex_chat/bar.ex", "defmodule RetroHexChat.Bar do\nend\n")

    write(root, "#{@web}/lib/retro_hex_chat_web/live/page_live.ex", """
    defmodule RetroHexChatWeb.PageLive do
      defmodule Row do
      end
    end
    """)

    write(root, "#{@web}/lib/retro_hex_chat_web/live/page_live.html.heex", "<p></p>\n")

    write(root, "#{@domain}/test/retro_hex_chat/foo_test.exs", """
    defmodule RetroHexChat.FooTest do
      alias RetroHexChat.{Foo}
      test "x", do: Foo.x()
    end
    """)

    write(root, "#{@domain}/test/retro_hex_chat/bar_test.exs", """
    defmodule RetroHexChat.BarTest do
      alias RetroHexChat.Bar, as: B
      test "x", do: B.x()
    end
    """)

    write(root, "#{@web}/test/retro_hex_chat_web/live/page_test.exs", """
    defmodule RetroHexChatWeb.PageTest do
      test "x", %{conn: conn, id: id}, do: live(conn, "/page/\#{id}?tab=1")
    end
    """)

    write(root, "#{@web}/test/retro_hex_chat_web/live/page_feature_test.exs", """
    defmodule RetroHexChatWeb.PageFeatureTest do
      @moduletag :liveview_feature
      test "x", %{conn: conn}, do: live(conn, ~p"/page/1")
    end
    """)

    write(root, "#{@web}/test/retro_hex_chat_web/unrelated_test.exs", """
    defmodule RetroHexChatWeb.UnrelatedTest do
      test "x", do: RetroHexChat.Other.x()
    end
    """)

    %{root: root, context: CITestSelection.context(root, @graph, @routes)}
  end

  defp write(root, path, body) do
    path = Path.join(root, path)
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, body)
  end

  defp selected({:ok, selection}), do: Enum.sort(selection.unit ++ selection.feature)

  test "one hop runs a module's own tests and its direct callers'", %{context: context} do
    selection =
      CITestSelection.select(["#{@domain}/lib/retro_hex_chat/foo.ex"], Map.put(context, :hops, 1))

    assert selected(selection) == [
             "#{@domain}/test/retro_hex_chat/bar_test.exs",
             "#{@domain}/test/retro_hex_chat/foo_test.exs"
           ]
  end

  test "the walk goes on through callers of callers", %{context: context} do
    selection = CITestSelection.select(["#{@domain}/lib/retro_hex_chat/foo.ex"], context)

    assert "#{@web}/test/retro_hex_chat_web/live/page_test.exs" in selected(selection)
    refute "#{@web}/test/retro_hex_chat_web/unrelated_test.exs" in selected(selection)
  end

  test "a test that visits a route served by an affected module runs", %{context: context} do
    {:ok, selection} = CITestSelection.select(["#{@domain}/lib/retro_hex_chat/bar.ex"], context)

    assert selection.unit == [
             "#{@domain}/test/retro_hex_chat/bar_test.exs",
             "#{@web}/test/retro_hex_chat_web/live/page_test.exs"
           ]

    assert selection.feature == ["#{@web}/test/retro_hex_chat_web/live/page_feature_test.exs"]
  end

  test "a template counts as a change to the module beside it", %{context: context} do
    selection =
      CITestSelection.select(["#{@web}/lib/retro_hex_chat_web/live/page_live.html.heex"], context)

    assert "#{@web}/test/retro_hex_chat_web/live/page_test.exs" in selected(selection)
  end

  test "a changed test file runs even when nothing else points at it", %{context: context} do
    file = "#{@web}/test/retro_hex_chat_web/unrelated_test.exs"

    assert selected(CITestSelection.select([file], context)) == [file]
  end

  test "a test named after a source file runs with it", %{root: root} do
    write(root, "#{@domain}/test/retro_hex_chat/elsewhere/foo_test.exs", "defmodule X do\nend\n")
    context = CITestSelection.context(root, @graph, @routes)

    assert "#{@domain}/test/retro_hex_chat/elsewhere/foo_test.exs" in selected(
             CITestSelection.select(["#{@domain}/lib/retro_hex_chat/foo.ex"], context)
           )
  end

  test "a hub does not pull in its dependents' tests", %{context: context} do
    selection =
      CITestSelection.select(
        ["#{@domain}/lib/retro_hex_chat/foo.ex"],
        Map.put(context, :hub_limit, 0)
      )

    assert selected(selection) == ["#{@domain}/test/retro_hex_chat/foo_test.exs"]
  end

  test "a removed source file runs everything", %{context: context} do
    assert {:full, reason} =
             CITestSelection.select(["#{@domain}/lib/retro_hex_chat/gone.ex"], context)

    assert reason =~ "removed"
  end

  test "a template no module embeds runs everything", %{context: context} do
    assert {:full, _} =
             CITestSelection.select(
               ["#{@web}/lib/retro_hex_chat_web/orphan/x.html.heex"],
               context
             )
  end

  test "nested modules belong to their file", %{context: context} do
    assert context.modules_by_file["#{@web}/lib/retro_hex_chat_web/live/page_live.ex"]
           |> Enum.sort() == [RetroHexChatWeb.PageLive, RetroHexChatWeb.PageLive.Row]
  end

  test "routes keep their module and their segments" do
    assert CITestSelection.parse_routes(@routes) == [
             {[], RetroHexChatWeb.HomeLive},
             {["page", ":id"], RetroHexChatWeb.PageLive}
           ]
  end
end

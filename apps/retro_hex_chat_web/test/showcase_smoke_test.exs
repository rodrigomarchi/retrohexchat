defmodule RetroHexChatWeb.ShowcaseSmokeTest do
  use RetroHexChatWeb.ConnCase, async: true

  alias RetroHexChatWeb.ShowcaseCatalog

  @showcase_routes ShowcaseCatalog.paths()

  for route <- @showcase_routes do
    @tag :showcase
    test "GET #{route} returns 200", %{conn: conn} do
      conn = get(conn, unquote(route))
      assert conn.status == 200, "#{unquote(route)} returned #{conn.status}"
    end
  end

  describe "catalog" do
    @tag :showcase
    test "every entry is a reachable route" do
      routes =
        RetroHexChatWeb.Router
        |> Phoenix.Router.routes()
        |> Enum.filter(&(&1.verb == :get and String.starts_with?(&1.path, "/showcase")))
        |> MapSet.new(& &1.path)

      catalog = MapSet.new(ShowcaseCatalog.paths())

      assert MapSet.equal?(catalog, routes),
             """
             The catalog and the router disagree.

             only in the catalog: #{inspect(MapSet.difference(catalog, routes))}
             only in the router:  #{inspect(MapSet.difference(routes, catalog))}
             """
    end

    @tag :showcase
    test "ids are unique" do
      ids = Enum.map(ShowcaseCatalog.entries(), & &1.id)
      assert ids == Enum.uniq(ids)
    end

    @tag :showcase
    test "every entry belongs to a declared group" do
      groups = MapSet.new(ShowcaseCatalog.groups(), & &1.key)

      for entry <- ShowcaseCatalog.entries() do
        assert entry.group in groups, "#{entry.id} has unknown group #{inspect(entry.group)}"
      end
    end

    @tag :showcase
    test "group counts add up to the catalog" do
      counted = ShowcaseCatalog.groups() |> Enum.map(& &1.count) |> Enum.sum()
      assert counted == length(ShowcaseCatalog.entries())
    end

    @tag :showcase
    test "every entry renders an icon that exists" do
      for entry <- ShowcaseCatalog.entries() do
        assert function_exported?(RetroHexChatWeb.Icons, entry.icon, 1),
               "#{entry.id} points at missing icon #{inspect(entry.icon)}"
      end
    end
  end

  # A showcase page draws a component's real controls with nothing behind them,
  # so every one of those clicks arrives as an event the page never declared.
  # Without a clause to catch it the LiveView exits, and the page a reader came
  # to look at disappears under them. Twenty-three pages shipped that way: the
  # buttons rendered, and the first click took the page down.
  describe "the controls a showcase page draws" do
    @tag :showcase
    test "every page answers an event it never declared" do
      for module <- showcase_modules() do
        assert function_exported?(module, :handle_event, 3),
               "#{inspect(module)} draws controls but declares no handle_event/3"

        assert {:noreply, _socket} =
                 module.handle_event(
                   "an-event-this-page-never-declared",
                   %{},
                   %Phoenix.LiveView.Socket{}
                 ),
               "#{inspect(module)} does not answer an event it never declared"
      end
    end

    defp showcase_modules do
      {:ok, modules} = :application.get_key(:retro_hex_chat_web, :modules)

      modules
      |> Enum.filter(
        &String.starts_with?(Atom.to_string(&1), "Elixir.RetroHexChatWeb.ShowcaseLive.")
      )
      |> Enum.filter(&function_exported?(&1, :render, 1))
    end
  end
end

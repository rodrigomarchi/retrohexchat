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
end

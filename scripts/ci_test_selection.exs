defmodule CITestSelection do
  @moduledoc false

  # Picks the ExUnit files a diff can reach, for `make ci` while iterating.
  #
  # Following every dependency transitively selects the whole suite here: the
  # Router, the Endpoint and Gettext sit on almost every path, so nearly every
  # file reaches nearly every other. The walk stops at those hubs instead:
  #
  #   * a changed or new test file runs, and so does a test named after a
  #     changed file (`construct_test.exs` for `construct.ex`);
  #   * a changed lib file affects its own modules and, walking the xref graph
  #     back through its callers, theirs -- except past a hub, a file with more
  #     direct callers than @hub_limit;
  #   * a test runs when it names an affected module, or visits a route an
  #     affected module serves (`live(conn, "/chat/help")`).
  #
  # What the walk cannot see -- a module reached through a hub, a message sent
  # by name -- is the full suite's job: `make ci.full`, which `make deploy`
  # runs before anything ships.

  @apps ["apps/retro_hex_chat", "apps/retro_hex_chat_web"]

  # Measured against the last 400 commits, on the 201 that changed source and
  # tests together: with these values the selection holds 96.6% of the test
  # files those commits touched (80% on commits of one or two source files)
  # and runs a median of 30% of the suite. One hop held 95.3% (68%); walks
  # longer than five hops change nothing, because they end at hubs.
  @hops 5
  # More direct callers than this makes a file a hub (see direct_dependents/2).
  @hub_limit 20
  # More test files visiting a route, or naming a module, than these makes it
  # a hub of the suite (see reaches?/3).
  @route_hub_limit 20
  @ref_hub_limit 25

  @type context :: %{
          root: String.t(),
          graph: %{String.t() => [String.t()]},
          modules_by_file: %{String.t() => [module()]},
          tests: [test_file()],
          routes: [{[String.t()], module()}]
        }

  @type test_file :: %{
          path: String.t(),
          refs: MapSet.t(module()),
          paths: [[String.t() | :any]],
          feature: :none | :some | :all
        }

  # --- selection ---

  @doc """
  Returns `{:ok, %{unit: files, feature: files, affected_modules: names}}`
  with the test files to run per suite, or `{:full, reason}` when the diff
  holds something the selection cannot reason about.
  """
  def select(changed, context) do
    case Enum.find_value(changed, &unselectable(&1, context)) do
      nil -> {:ok, do_select(changed, context)}
      reason -> {:full, reason}
    end
  end

  defp unselectable(file, context) do
    cond do
      lib_source?(file) and not File.exists?(Path.join(context.root, file)) ->
        "#{file} was removed; the tests that named its modules cannot be found"

      String.ends_with?(file, ".heex") and lib_source?(file) and
          template_owner(file, context) == nil ->
        "#{file} has no module that embeds it"

      true ->
        nil
    end
  end

  defp do_select(changed, context) do
    changed_tests =
      changed
      |> Enum.filter(&test_file?/1)
      |> Enum.filter(&File.exists?(Path.join(context.root, &1)))
      |> MapSet.new()

    sources = changed |> Enum.filter(&lib_source?/1) |> Enum.map(&source_file(&1, context))
    affected_files = sources |> Enum.reject(&is_nil/1) |> MapSet.new() |> with_dependents(context)

    affected =
      affected_files
      |> Enum.flat_map(&Map.get(context.modules_by_file, &1, []))
      |> MapSet.new()

    changed_files = sources |> Enum.reject(&is_nil/1) |> MapSet.new()
    changed_modules = modules_of(changed_files, context)
    direct = changed_files |> with_dependents(Map.put(context, :hops, 1)) |> modules_of(context)
    names = Enum.map(changed_files, &Path.basename(&1, ".ex"))

    scope = %{affected: affected, direct: direct, changed: changed_modules}

    selected =
      for test <- context.tests,
          MapSet.member?(changed_tests, test.path) or named_after?(test, names) or
            reaches?(test, scope, context),
          do: test

    %{
      unit: for(t <- selected, t.feature != :all, do: t.path),
      feature: for(t <- selected, t.feature != :none, do: t.path),
      affected_modules: affected |> Enum.map(&inspect/1) |> Enum.sort()
    }
  end

  defp modules_of(files, context) do
    files |> Enum.flat_map(&Map.get(context.modules_by_file, &1, [])) |> MapSet.new()
  end

  # `construct_test.exs` and `construct_feature_test.exs` test `construct.ex`,
  # and `address_book_test.exs` tests `address_book_dialog.ex`, wherever each
  # one sits.
  defp named_after?(test, names) do
    tested = test.path |> Path.basename("_test.exs") |> String.replace_suffix("_feature", "")
    Enum.any?(names, &(&1 == tested or String.starts_with?(&1, tested <> "_")))
  end

  defp with_dependents(files, context),
    do: with_dependents(files, files, Map.get(context, :hops, @hops), context)

  defp with_dependents(acc, _frontier, 0, _context), do: acc

  defp with_dependents(acc, frontier, hops, context) do
    next =
      frontier
      |> Enum.flat_map(&direct_dependents(&1, context))
      |> MapSet.new()
      |> MapSet.difference(acc)

    with_dependents(MapSet.union(acc, next), next, hops - 1, context)
  end

  # A hub (the Router, Gettext, a shared component) is referenced from
  # everywhere; walking out of it selects the suite without saying anything
  # about the change. Its own tests and the tests that name it still run.
  defp direct_dependents(file, context) do
    dependents = Map.get(context.graph, file, [])
    if length(dependents) > Map.get(context, :hub_limit, @hub_limit), do: [], else: dependents
  end

  # What most of the suite uses says nothing about what one test exercises:
  # nearly every chat test opens a channel through `Channels.Server` and
  # visits `/`, which serves the whole desktop. A module many tests name
  # counts only when the change is in it or one call away; a route many tests
  # visit, only when the module serving it changed.
  defp reaches?(test, scope, context) do
    {hub_refs, refs} = Enum.split_with(test.refs, &MapSet.member?(context.ref_hubs, &1))

    {hub_routes, routes} =
      Enum.split_with(test.route_modules, &MapSet.member?(context.route_hubs, &1))

    Enum.any?(refs ++ routes, &MapSet.member?(scope.affected, &1)) or
      Enum.any?(hub_refs, &MapSet.member?(scope.direct, &1)) or
      Enum.any?(hub_routes, &MapSet.member?(scope.changed, &1))
  end

  defp route_modules(paths, routes) do
    for path <- paths,
        {route, module} <- routes,
        route_matches?(route, path),
        uniq: true,
        do: module
  end

  defp source_file(file, context) do
    if String.ends_with?(file, ".heex"), do: template_owner(file, context), else: file
  end

  # A template belongs to the module beside it (`foo_live.html.heex` and
  # `foo_live.ex`) or to the module named after its folder, which
  # `embed_templates "folder/*"`.
  defp template_owner(file, context) do
    base = file |> Path.basename() |> String.split(".") |> hd()
    dir = Path.dirname(file)

    [Path.join(dir, base <> ".ex"), dir <> ".ex"]
    |> Enum.find(&File.exists?(Path.join(context.root, &1)))
  end

  defp route_matches?(route, path) when length(route) != length(path), do: false

  defp route_matches?(route, path) do
    route
    |> Enum.zip(path)
    |> Enum.all?(fn
      {_segment, :any} -> true
      {":" <> _param, _} -> true
      {"*" <> _glob, _} -> true
      {segment, segment} -> true
      _ -> false
    end)
  end

  defp lib_source?(file) do
    Enum.any?(@apps, &String.starts_with?(file, &1 <> "/lib/")) and
      (String.ends_with?(file, ".ex") or String.ends_with?(file, ".heex"))
  end

  defp test_file?(file) do
    Enum.any?(@apps, &String.starts_with?(file, &1 <> "/test/")) and
      String.ends_with?(file, "_test.exs")
  end

  # --- context ---

  @doc "Builds the context from the source tree, an xref graph and the router's routes."
  def context(root, xref_graph, routes_output) do
    lib_files = Enum.flat_map(@apps, &Path.wildcard(Path.join([root, &1, "lib", "**", "*.ex"])))

    routes = parse_routes(routes_output)

    tests =
      @apps
      |> Enum.flat_map(&Path.wildcard(Path.join([root, &1, "test", "**", "*_test.exs"])))
      |> Enum.map(&test_file(&1, root))
      |> Enum.map(&Map.put(&1, :route_modules, route_modules(&1.paths, routes)))

    %{
      root: root,
      graph: dependents(xref_graph, root),
      modules_by_file:
        Map.new(lib_files, fn path -> {Path.relative_to(path, root), defined_modules(path)} end),
      tests: tests,
      routes: routes,
      route_hubs: popular(tests, :route_modules, @route_hub_limit),
      ref_hubs: popular(tests, :refs, @ref_hub_limit)
    }
  end

  defp popular(tests, key, limit) do
    tests
    |> Enum.flat_map(&Enum.to_list(Map.fetch!(&1, key)))
    |> Enum.frequencies()
    |> Enum.filter(fn {_module, count} -> count > limit end)
    |> MapSet.new(&elem(&1, 0))
  end

  @doc """
  Inverts `mix xref graph --format json` (file => files it references) into
  file => files that reference it, with paths made relative to the umbrella.
  The graph is the web app's with `--include-siblings`, so its paths are
  relative to whichever app holds the file.
  """
  def dependents(xref_graph, root) do
    resolve = fn path -> resolve_app_path(path, root) end

    Enum.reduce(xref_graph, %{}, fn {source, sinks}, acc ->
      source = resolve.(source)

      Enum.reduce(Map.keys(sinks), acc, fn sink, inner ->
        Map.update(inner, resolve.(sink), [source], &[source | &1])
      end)
    end)
  end

  defp resolve_app_path(path, root) do
    @apps
    |> Enum.map(&Path.join(&1, path))
    |> Enum.find(Path.join(List.last(@apps), path), &File.exists?(Path.join(root, &1)))
  end

  @doc "Parses `mix phx.routes` output into `{segments, module}` pairs."
  def parse_routes(output) do
    output
    |> String.split("\n", trim: true)
    |> Enum.flat_map(fn line ->
      tokens = String.split(line)

      with path when is_binary(path) <- Enum.find(tokens, &String.starts_with?(&1, "/")),
           module when is_binary(module) <-
             tokens
             |> Enum.drop_while(&(&1 != path))
             |> Enum.find(&(&1 =~ ~r/^[A-Z][A-Za-z0-9_]*(\.[A-Z][A-Za-z0-9_]*)+$/)) do
        [{segments(path), Module.concat([module])}]
      else
        _ -> []
      end
    end)
  end

  defp segments(path), do: String.split(path, "/", trim: true)

  defp test_file(path, root) do
    source = File.read!(path)
    ast = quoted(source, path)

    feature =
      cond do
        source =~ ~r/@moduletag\s+(:liveview_feature|liveview_feature: true)/ -> :all
        String.contains?(source, "liveview_feature") -> :some
        true -> :none
      end

    %{
      path: Path.relative_to(path, root),
      refs: referenced_modules(ast),
      paths: visited_paths(ast),
      feature: feature
    }
  end

  defp quoted(source, path) do
    case Code.string_to_quoted(source, file: path, columns: false) do
      {:ok, ast} -> ast
      {:error, _} -> nil
    end
  end

  @doc "Every module a file defines, nested `defmodule`s included."
  def defined_modules(path) do
    path |> File.read!() |> quoted(path) |> collect_defined(nil, [])
  end

  defp collect_defined({:defmodule, _, [{:__aliases__, _, parts}, body]}, parent, acc) do
    module = if parent, do: Module.concat([parent | parts]), else: Module.concat(parts)
    collect_defined(body, module, [module | acc])
  end

  defp collect_defined({_, _, args}, parent, acc) when is_list(args),
    do: Enum.reduce(args, acc, &collect_defined(&1, parent, &2))

  defp collect_defined(list, parent, acc) when is_list(list),
    do: Enum.reduce(list, acc, &collect_defined(&1, parent, &2))

  defp collect_defined({left, right}, parent, acc),
    do: collect_defined(right, parent, collect_defined(left, parent, acc))

  defp collect_defined(_other, _parent, acc), do: acc

  @doc "Every module a file names, with its `alias`es expanded."
  def referenced_modules(nil), do: MapSet.new()

  def referenced_modules(ast) do
    aliases = collect_aliases(ast)

    {_, refs} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:__aliases__, _, [head | rest] = parts} = node, acc when is_atom(head) ->
          full = if Map.has_key?(aliases, head), do: aliases[head] ++ rest, else: parts
          {node, MapSet.put(acc, Module.concat(full))}

        node, acc ->
          {node, acc}
      end)

    refs
  end

  defp collect_aliases(ast) do
    {_, aliases} =
      Macro.prewalk(ast, %{}, fn
        {:alias, _, [{:__aliases__, _, parts}, [as: {:__aliases__, _, [as]}]]} = node, acc ->
          {node, Map.put(acc, as, parts)}

        {:alias, _, [{:__aliases__, _, parts} | _]} = node, acc ->
          {node, Map.put(acc, List.last(parts), parts)}

        {:alias, _, [{{:., _, [{:__aliases__, _, base}, :{}]}, _, children} | _]} = node, acc ->
          acc =
            Enum.reduce(children, acc, fn
              {:__aliases__, _, parts}, inner -> Map.put(inner, List.last(parts), base ++ parts)
              _other, inner -> inner
            end)

          {node, acc}

        node, acc ->
          {node, acc}
      end)

    aliases
  end

  @doc ~S"""
  Every request path a test file spells out, as segments, with an
  interpolation (`"/call/#{token}"`) matching any segment.
  """
  def visited_paths(nil), do: []

  def visited_paths(ast) do
    {_, paths} =
      Macro.prewalk(ast, [], fn
        "/" <> _ = literal, acc ->
          {literal, [path_segments([literal]) | acc]}

        {:<<>>, _, ["/" <> _ | _] = parts} = node, acc ->
          {node, [path_segments(parts) | acc]}

        node, acc ->
          {node, acc}
      end)

    Enum.uniq(paths)
  end

  defp path_segments(parts) do
    parts
    |> Enum.map(fn
      text when is_binary(text) -> text
      _interpolation -> "\0"
    end)
    |> Enum.join()
    |> String.split(["?", "#"], parts: 2)
    |> hd()
    |> String.split("/", trim: true)
    |> Enum.map(fn segment -> if String.contains?(segment, "\0"), do: :any, else: segment end)
  end
end

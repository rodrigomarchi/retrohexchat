defmodule RetroHexChatWeb.EndpointStaticTest do
  @moduledoc """
  Static asset serving, driven through the endpoint itself.

  `Plug.Static` matches its allow-list against the first path segment, so a list
  naming `favicon.ico` never serves `favicon-<digest>.ico` — the name
  `~p"/favicon.ico"` resolves to once assets are digested. Only a digested build
  shows it, which is why the icon 404'd in production while every test passed.
  """
  use RetroHexChatWeb.ConnCase, async: false

  alias RetroHexChat.VirtualSpace.Map, as: SpaceMap
  alias RetroHexChatWeb.SpaceAssets
  alias RetroHexChatWeb.Wallpaper

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

  # `Plug.Static` only grants `immutable` to a request carrying `?vsn=`, which
  # `~p` appends from the digest manifest. Two kinds of asset never get one, and
  # both showed up in production's nginx log as a 304 per page view: esbuild's
  # dynamic-import chunks, whose URL is written into the bundle by the bundler
  # rather than by a template, and any path a template hardcoded as a string.
  describe "cache headers" do
    test "a content-hashed chunk is immutable without a vsn", %{conn: conn} do
      dir = Path.join(Application.app_dir(:retro_hex_chat_web, "priv/static"), "assets/js/chunks")
      File.mkdir_p!(dir)
      path = Path.join(dir, "app-chunk-CACHETEST.js")
      File.write!(path, "export const x = 1;")
      on_exit(fn -> File.rm_rf!(path) end)

      conn = get(conn, "/assets/js/chunks/app-chunk-CACHETEST.js")

      assert response(conn, 200)

      assert get_resp_header(conn, "cache-control") == [
               "public, max-age=31536000, immutable"
             ]
    end

    test "an asset addressed with a vsn is immutable", %{conn: conn} do
      url = with_static_file("favicon-cachetest.ico", "icon")
      conn = get(conn, url <> "?vsn=d")

      assert response(conn, 200)
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
    end
  end

  # `priv/static`'s ignore rule for digest artefacts is `*-[0-9a-f]*.*`, and the
  # `d` of `-desktop` is a hex digit: a wallpaper named `wallpaper-desktop.webp`
  # is untracked by git, so it exists on the machine that made it and nowhere
  # else. Nothing in the app fails without it — the desk just falls back to
  # teal — so this is the only place the loss would ever be noticed.
  describe "desktop wallpaper" do
    test "both wallpapers are really served", %{conn: conn} do
      for url <- [Wallpaper.desktop_url(), Wallpaper.mobile_url()] do
        conn = get(conn, url)

        assert response(conn, 200)
        assert get_resp_header(conn, "content-type") == ["image/webp"]
      end
    end

    test "the files are tracked by git", %{conn: _conn} do
      for url <- [Wallpaper.desktop_url(), Wallpaper.mobile_url()] do
        {out, status} =
          System.cmd("git", ["check-ignore", "apps/retro_hex_chat_web/priv/static" <> url],
            cd: repo_root(),
            stderr_to_stdout: true
          )

        assert status == 1,
               "the wallpaper is gitignored and will be missing from the release: #{out}"
      end
    end
  end

  # The space sheets are the heaviest thing the app serves and the only art with
  # no fallback underneath: a class whose sheet 404s draws a shadow and a floating
  # nickname with nobody inside. Nothing else asserts they are reachable.
  describe "virtual-space sprite sheets" do
    test "every sheet the atlas can ask for is really served", %{conn: conn} do
      for {id, url} <- SpaceAssets.sheet_urls() do
        conn = get(conn, url)

        assert response(conn, 200), "#{id} is not served at #{url}"
        assert get_resp_header(conn, "content-type") == ["image/webp"]
      end
    end

    test "every map's tileset is served, at the digested url the client is given" do
      for map_id <- SpaceMap.ids() do
        {:ok, definition} = SpaceMap.get(map_id)
        %{tilesets: tilesets} = SpaceAssets.digest_map(definition)

        for %{src: src} <- tilesets do
          conn = get(build_conn(), src)

          assert response(conn, 200), "#{map_id}'s tileset is not served at #{src}"
          assert get_resp_header(conn, "content-type") == ["image/webp"]
        end
      end
    end

    test "the picker preview sheet is really served", %{conn: conn} do
      conn = get(conn, ~p"/images/space/charsel.webp")

      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") == ["image/webp"]
    end

    test "the sheets are tracked by git" do
      urls = Map.values(SpaceAssets.sheet_urls()) ++ ["/images/space/charsel.webp"]

      for url <- urls do
        {out, status} =
          System.cmd("git", ["check-ignore", "apps/retro_hex_chat_web/priv/static" <> url],
            cd: repo_root(),
            stderr_to_stdout: true
          )

        assert status == 1,
               "the sheet is gitignored and will be missing from the release: #{out}"
      end
    end
  end

  defp repo_root do
    :retro_hex_chat_web |> Application.app_dir() |> Path.join("../../../..") |> Path.expand()
  end

  describe "static paths in templates" do
    @static_roots ~w(images fonts assets)

    test "no template hardcodes a static path that ~p should version" do
      offenders =
        "lib/**/*.{ex,heex}"
        |> Path.wildcard()
        |> Enum.flat_map(fn file ->
          file
          |> File.read!()
          # The showcase renders escaped markup as documentation; those are
          # printed examples, not references the browser ever resolves.
          |> String.replace(~r/&lt;.*?&gt;/s, "")
          |> then(&Regex.scan(~r/(?:src|href)="\/(#{Enum.join(@static_roots, "|")})\/[^"]+"/, &1))
          |> Enum.map(fn [match | _] -> "#{file}: #{match}" end)
        end)

      assert offenders == [],
             """
             These resolve without a ?vsn, so the browser revalidates them on every
             page load instead of never asking again. Use ~p"/images/…".

             #{Enum.join(offenders, "\n")}
             """
    end
  end
end

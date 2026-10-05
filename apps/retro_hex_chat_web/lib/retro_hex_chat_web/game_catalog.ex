defmodule RetroHexChatWeb.GameCatalog do
  @moduledoc """
  Every game the public catalogue has a page for, as the pages need it.

  Two domain catalogues feed it: the solo arcade (`RetroHexChat.Arcade.Catalog`)
  and the multiplayer games (`RetroHexChat.Games.Catalog`). A multiplayer
  game's modes — "Hex Tennis: Quick Match" — are listed in the domain as games
  that name their game in `mode_of`; a page per mode would be the same page
  with one sentence changed, so each game's page lists its modes instead.

  No text is written here. Names, taglines and descriptions are the ones the
  in-app library already shows and already translates. The longer arcade prose
  in `Arcade.Content` is deliberately not used: it is what each game's help
  page says, and the same paragraphs on two public URLs would leave a search
  engine to pick one of them, quite possibly the help page.

  A game's picture is a screenshot, captured by `make games.shots` (or, for a
  game the capture cannot reach, imported from a published one) into
  `priv/static/images/games/`, with a 1200×630 JPEG share card beside it in
  `og/` and a `manifest.json` of their sizes and sources. The
  manifest is read at compile time, so a game added to a catalogue without a
  screenshot has `screenshot: nil` — and the test that walks the catalogue says
  so before a page ships without one.
  """

  alias RetroHexChat.Arcade.Catalog, as: Arcade
  alias RetroHexChat.Games.Catalog, as: Games
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Endpoint

  @shots_dir Path.expand("../../priv/static/images/games", __DIR__)
  @manifest_path Path.join(@shots_dir, "manifest.json")
  @external_resource @manifest_path

  @manifest (case File.read(@manifest_path) do
               {:ok, body} -> Jason.decode!(body)
               {:error, _reason} -> %{}
             end)

  @type kind :: :arcade | :multiplayer
  @type screenshot :: %{
          path: String.t(),
          width: pos_integer(),
          height: pos_integer(),
          og_path: String.t(),
          og_width: pos_integer(),
          og_height: pos_integer()
        }
  @type mode :: %{name: String.t(), tagline: String.t()}
  @type game :: %{
          id: String.t(),
          slug: String.t(),
          kind: kind(),
          name: String.t(),
          tagline: String.t(),
          description: String.t(),
          controls: String.t(),
          modes: [mode()],
          engine: atom() | nil,
          icon: String.t(),
          help_topic: String.t(),
          screenshot: screenshot() | nil
        }

  @doc "Every game with a page, arcade first, each kind in its catalogue's order."
  @spec list() :: [game()]
  def list, do: arcade_games() ++ multiplayer_games()

  @doc "The games of one kind."
  @spec list(kind()) :: [game()]
  def list(:arcade), do: arcade_games()
  def list(:multiplayer), do: multiplayer_games()

  @doc "The game a public URL names, by its slug."
  @spec get(String.t()) :: {:ok, game()} | :error
  def get(slug) when is_binary(slug) do
    case Enum.find(list(), &(&1.slug == slug)) do
      nil -> :error
      game -> {:ok, game}
    end
  end

  @doc "Every slug with a page, for the sitemap."
  @spec slugs() :: [String.t()]
  def slugs, do: Enum.map(list(), & &1.slug)

  @doc """
  A few other games worth a click from `game`'s page: the same engine for the
  arcade, the other multiplayer games otherwise.
  """
  @spec related(game(), pos_integer()) :: [game()]
  def related(game, count \\ 4) do
    candidates = Enum.reject(list(game.kind), &(&1.id == game.id))

    {same, rest} =
      Enum.split_with(candidates, &(game.kind == :arcade and &1.engine == game.engine))

    Enum.take(same ++ rest, count)
  end

  @doc """
  Where playing the game starts. It needs a nickname, so a public page hands
  this to its Connect window, which lands the reader here after signing in:
  the chat with the arcade open on the game, or the game's own surface.
  """
  @spec play_path(game()) :: String.t()
  def play_path(%{kind: :arcade, id: id}), do: Paths.chat_arcade_path(id)
  def play_path(%{kind: :multiplayer, id: id}), do: Paths.play_path(id)

  @doc """
  What the screenshot capture needs to open each game, as plain data — the
  capture script is JavaScript and reads it as JSON.
  """
  @spec capture_targets() :: [map()]
  def capture_targets do
    Enum.map(Arcade.list_games(), fn game ->
      %{slug: slug(game.id), kind: "arcade", engine: game.engine, url: Arcade.game_url(game)}
    end) ++
      Enum.map(list(:multiplayer), &%{slug: &1.slug, kind: "multiplayer", path: play_path(&1)})
  end

  @doc "A game's page, unprefixed — the canonical address every locale's version names."
  @spec page_path(game()) :: String.t()
  def page_path(game), do: "/games/#{game.slug}"

  @doc "The public slug of a catalogue id: `doom_shareware` reads `doom-shareware`."
  @spec slug(String.t()) :: String.t()
  def slug(id), do: String.replace(id, "_", "-")

  defp arcade_games do
    Enum.map(Arcade.list_games(), fn game ->
      %{
        id: game.id,
        slug: slug(game.id),
        kind: :arcade,
        name: game.name,
        tagline: game.tagline,
        description: game.description,
        controls: game.controls,
        modes: [],
        engine: game.engine,
        icon: game.icon,
        help_topic: "feature-arcade-" <> slug(game.id),
        screenshot: screenshot(slug(game.id))
      }
    end)
  end

  defp multiplayer_games do
    Enum.map(Games.base_games(), fn game ->
      modes =
        game.id
        |> Games.modes_of()
        |> Enum.map(&%{name: mode_name(&1.name, game.name), tagline: &1.tagline})

      %{
        id: game.id,
        slug: slug(game.id),
        kind: :multiplayer,
        name: game.name,
        tagline: game.tagline,
        description: game.description,
        controls: game.controls,
        modes: modes,
        engine: nil,
        icon: game.icon,
        help_topic: "feature-retro-games",
        screenshot: screenshot(slug(game.id))
      }
    end)
  end

  # A mode is named "Hex Tennis: Quick Match"; on the game's own page the game
  # is already the heading, so the mode is just "Quick Match".
  defp mode_name(name, base_name), do: String.replace_prefix(name, base_name <> ": ", "")

  defp screenshot(slug) do
    # The page shows WebP; a share card is JPEG at the size every platform
    # crops to, because LinkedIn and WhatsApp do not reliably show WebP.
    case Map.get(@manifest, slug) do
      %{
        "width" => width,
        "height" => height,
        "og" => %{"width" => og_width, "height" => og_height}
      } ->
        %{
          path: Endpoint.static_path("/images/games/#{slug}.webp"),
          width: width,
          height: height,
          og_path: Endpoint.static_path("/images/games/og/#{slug}.jpg"),
          og_width: og_width,
          og_height: og_height
        }

      _missing ->
        nil
    end
  end
end

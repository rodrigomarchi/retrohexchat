defmodule RetroHexChatWeb.GameCatalog do
  @moduledoc """
  Every game the public catalogue has a page for, as the pages need it.

  Two domain catalogues feed it: the solo arcade (`RetroHexChat.Arcade.Catalog`)
  and the multiplayer games (`RetroHexChat.Games.Catalog`). A multiplayer
  game's modes — "Hex Tennis: Quick Match" — are listed in the domain as games
  that name their game in `mode_of`; a page per mode would be the same page
  with one sentence changed, so each game's page lists its modes instead.

  No text is written here. Names, taglines and descriptions are the ones the
  in-app library already shows and already translates. An arcade game also
  carries its sheet — the paragraphs, the key table and the tips of
  `Arcade.Content` — because its public page and the in-app Arcade show the
  same sheet (`GameSheet`), so a reader finds the same game in both places.

  A game's picture is a screenshot, captured by `make games.shots` (or, for a
  game the capture cannot reach, imported from a published one) into
  `priv/static/images/games/`, with a 1200×630 JPEG share card beside it in
  `og/` and a `manifest.json` of their sizes and sources. The
  manifest is read at compile time, so a game added to a catalogue without a
  screenshot has `screenshot: nil` — and the test that walks the catalogue says
  so before a page ships without one.
  """

  alias RetroHexChat.Arcade.Catalog, as: Arcade
  alias RetroHexChat.Arcade.Content
  alias RetroHexChat.Games.Catalog, as: Games
  alias RetroHexChatWeb.App.Paths
  alias RetroHexChatWeb.Endpoint
  alias RetroHexChatWeb.PublicPages

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
  @type mode :: %{id: String.t(), name: String.t(), tagline: String.t()}
  @type group :: %{engine: atom(), name: String.t(), games: [game()]}
  @type game :: %{
          id: String.t(),
          slug: String.t(),
          kind: kind(),
          name: String.t(),
          tagline: String.t(),
          description: String.t(),
          controls: String.t(),
          about: [String.t()],
          keys: [{String.t(), String.t()}],
          tips: [String.t()],
          modes: [mode()],
          engine: atom() | nil,
          engine_name: String.t() | nil,
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

  @doc """
  The arcade's games under their engines, in the catalogue's order — the one
  grouping the public catalogue, the in-app Arcade and its help all show.
  """
  @spec arcade_groups() :: [group()]
  def arcade_groups do
    games = Enum.group_by(arcade_games(), & &1.engine)

    for engine <- Arcade.engines(), Map.has_key?(games, engine) do
      %{engine: engine, name: Arcade.engine_name(engine), games: Map.fetch!(games, engine)}
    end
  end

  @doc """
  `arcade_groups/0` as a list of links: each game beside its page, in the
  reader's language — what every public list of the arcade draws.
  """
  @spec arcade_cards() :: [%{engine: atom(), name: String.t(), cards: [map()]}]
  def arcade_cards do
    for group <- arcade_groups() do
      cards = Enum.map(group.games, &%{game: &1, path: PublicPages.localized_path(page_path(&1))})
      %{engine: group.engine, name: group.name, cards: cards}
    end
  end

  @doc "An arcade game by its catalogue id, as the in-app Arcade opens it."
  @spec get_arcade(String.t()) :: {:ok, game()} | :error
  def get_arcade(id) when is_binary(id) do
    case Enum.find(arcade_games(), &(&1.id == id)) do
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
  capture script is JavaScript and reads it as JSON. Read from the catalogues
  alone: the capture runs with the application stopped (`mix run --no-start`),
  where nothing that asks the endpoint (a screenshot's path, a verified
  route) can be built.
  """
  @spec capture_targets() :: [map()]
  def capture_targets do
    Enum.map(Arcade.list_games(), fn game ->
      %{slug: slug(game.id), kind: "arcade", engine: game.engine, url: Arcade.game_url(game)}
    end) ++
      Enum.map(Games.base_games(), fn game ->
        # The page's route written out: a verified route asks the endpoint too.
        %{slug: slug(game.id), kind: "multiplayer", path: "/play/#{game.id}"}
      end)
  end

  @doc "A game's page, unprefixed — the canonical address every locale's version names."
  @spec page_path(game()) :: String.t()
  def page_path(game), do: "/games/#{game.slug}"

  @doc "The public slug of a catalogue id: `doom_shareware` reads `doom-shareware`."
  @spec slug(String.t()) :: String.t()
  defdelegate slug(id), to: Games

  defp arcade_games do
    Enum.map(Arcade.list_games(), fn game ->
      sheet = sheet(game)

      %{
        id: game.id,
        slug: slug(game.id),
        kind: :arcade,
        name: game.name,
        tagline: game.tagline,
        description: game.description,
        controls: game.controls,
        about: sheet.about,
        keys: sheet.controls,
        tips: sheet.tips,
        modes: [],
        engine: game.engine,
        engine_name: Arcade.engine_name(game.engine),
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
        |> Enum.map(&%{id: &1.id, name: mode_name(&1.name, game.name), tagline: &1.tagline})

      %{
        id: game.id,
        slug: slug(game.id),
        kind: :multiplayer,
        name: game.name,
        tagline: game.tagline,
        description: game.description,
        controls: game.controls,
        about: [],
        keys: [],
        tips: [],
        modes: modes,
        engine: nil,
        engine_name: nil,
        icon: game.icon,
        help_topic: "feature-" <> slug(game.id),
        screenshot: screenshot(slug(game.id))
      }
    end)
  end

  # A game without written content still has a sheet: its description is
  # the About.
  defp sheet(game) do
    case Content.get_content(game.id) do
      {:ok, content} -> content
      {:error, :not_found} -> %{about: [game.description], controls: [], tips: []}
    end
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

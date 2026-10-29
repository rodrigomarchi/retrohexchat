defmodule RetroHexChat.Arcade.Catalog do
  @moduledoc """
  Registry of available single-player arcade games.
  Each game maps to a WASM engine (Doom, Quake, Quake II, Wolfenstein 3D,
  Half-Life, or ScummVM) with specific game data.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.CatalogText

  @type game :: %{
          id: String.t(),
          name: String.t(),
          tagline: String.t(),
          description: String.t(),
          engine: :doom | :quake | :quake2 | :wolfenstein | :halflife | :scummvm,
          controls: String.t(),
          icon: String.t()
        }

  @games [
    %{
      id: "doom_shareware",
      name: "DOOM: Knee-Deep in the Dead",
      tagline: dgettext_noop("arcade", "Episode 1 — The Original"),
      description:
        dgettext_noop(
          "arcade",
          "The original Episode 1 of DOOM (1993) — 9 levels of demon-infested corridors on Phobos. The shareware classic that started it all."
        ),
      engine: :doom,
      controls:
        dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_doom"
    },
    %{
      id: "freedoom1",
      name: "Freedoom: Phase 1",
      tagline: dgettext_noop("arcade", "36 levels of open-source doom"),
      description:
        dgettext_noop(
          "arcade",
          "A complete free replacement for Ultimate DOOM — 4 episodes, 36 levels. Original art, music, and levels under BSD license."
        ),
      engine: :doom,
      controls:
        dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_freedoom1"
    },
    %{
      id: "freedoom2",
      name: "Freedoom: Phase 2",
      tagline: dgettext_noop("arcade", "32 levels — Doom II compatible"),
      description:
        dgettext_noop(
          "arcade",
          "A complete free replacement for DOOM II — 32 levels with the Super Shotgun. Compatible with thousands of community-made PWAD mods."
        ),
      engine: :doom,
      controls:
        dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_freedoom2"
    },
    %{
      id: "freedm",
      name: "FreeDM",
      tagline: dgettext_noop("arcade", "Deathmatch arena — open source"),
      description:
        dgettext_noop(
          "arcade",
          "Free deathmatch-focused maps for DOOM. 32 arena-style levels designed for fast-paced multiplayer action. BSD license."
        ),
      engine: :doom,
      controls:
        dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_freedm"
    },
    %{
      id: "chex_quest",
      name: "Chex Quest",
      tagline: dgettext_noop("arcade", "The cereal box classic"),
      description:
        dgettext_noop(
          "arcade",
          "The legendary 1996 cereal box promotion — a kid-friendly total conversion of DOOM where you zap Flemoids with the Zorcher. 5 levels of nostalgia."
        ),
      engine: :doom,
      controls:
        dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_chex"
    },
    %{
      id: "hacx",
      name: "HacX: Twitch 'n Kill",
      tagline: dgettext_noop("arcade", "Cyberpunk total conversion"),
      description:
        dgettext_noop(
          "arcade",
          "A cyberpunk total conversion — hack through a dystopian future with new weapons, enemies, and levels. Standalone v1.2 IWAD."
        ),
      engine: :doom,
      controls:
        dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_hacx"
    },
    %{
      id: "rekkr",
      name: "REKKR: Sunken Land",
      tagline: dgettext_noop("arcade", "Viking-themed standalone"),
      description:
        dgettext_noop(
          "arcade",
          "A Viking-themed total conversion with hand-drawn pixel art. Battle through Norse-inspired levels with axes, bows, and runic magic."
        ),
      engine: :doom,
      controls:
        dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_rekkr"
    },
    %{
      id: "quake_shareware",
      name: "Quake: Dimension of the Doomed",
      tagline: dgettext_noop("arcade", "Episode 1 — The Original"),
      description:
        dgettext_noop(
          "arcade",
          "The original Episode 1 of Quake (1996) — full 3D FPS with Lovecraftian horrors. The shareware episode that pushed PC gaming into true 3D."
        ),
      engine: :quake,
      controls: dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use"),
      icon: "game_quake"
    },
    %{
      id: "librequake",
      name: "LibreQuake",
      tagline: dgettext_noop("arcade", "Open-source Quake replacement"),
      description:
        dgettext_noop(
          "arcade",
          "A complete free replacement for Quake — original levels, art, and music under BSD license. Community-made open-source content."
        ),
      engine: :quake,
      controls: dgettext_noop("arcade", "WASD move, Mouse aim, Left click fire, E use"),
      icon: "game_librequake"
    },
    %{
      id: "quake2_shareware",
      name: "Quake II: The Invasion",
      tagline: dgettext_noop("arcade", "Unit 1 — The Demo"),
      description:
        dgettext_noop(
          "arcade",
          "The official Quake II demo (1997) — full 3D FPS with Strogg invasion. Unit 1 of the singleplayer campaign. The shareware classic that defined online FPS."
        ),
      engine: :quake2,
      controls:
        dgettext_noop(
          "arcade",
          "WASD move, Mouse aim, Left click fire, E use, Space jump, C crouch, R reload"
        ),
      icon: "game_quake2"
    },
    %{
      id: "wolfenstein_3d",
      name: "Wolfenstein 3D: Escape from Castle",
      tagline: dgettext_noop("arcade", "Episode 1 — The Shareware Classic"),
      description:
        dgettext_noop(
          "arcade",
          "The grandfather of FPS games (1992) — 10 levels of castle-storming action. The shareware episode that launched the first-person shooter genre."
        ),
      engine: :wolfenstein,
      controls:
        dgettext_noop(
          "arcade",
          "Arrow keys move, Ctrl fire, Space open doors, Shift run, 1-4 weapons"
        ),
      icon: "game_wolfenstein"
    },
    %{
      id: "halflife_uplink",
      name: "Half-Life: Uplink",
      tagline: dgettext_noop("arcade", "The Official Demo — 3 Unique Missions"),
      description:
        dgettext_noop(
          "arcade",
          "The official Half-Life demo (1999) — 3 unique levels not found in the full game. Fight through Black Mesa's underground labs. Freely redistributable by Valve."
        ),
      engine: :halflife,
      controls:
        dgettext_noop(
          "arcade",
          "WASD move, Mouse aim, Left click fire, E use, Space jump, Shift crouch, R reload"
        ),
      icon: "game_halflife"
    },
    %{
      id: "scummvm_bass",
      name: "Beneath a Steel Sky",
      tagline: dgettext_noop("arcade", "Cyberpunk point & click adventure (1994)"),
      description:
        dgettext_noop(
          "arcade",
          "Escape Union City and uncover your past in this cyberpunk classic by Revolution Software. One of the greatest point & click adventures ever made."
        ),
      engine: :scummvm,
      controls:
        dgettext_noop(
          "arcade",
          "Left click interact/walk, Right click examine/verb menu, Drag inventory items to combine. F5 save/load, Ctrl+F5 options, Esc skip cutscene"
        ),
      icon: "game_bass"
    },
    %{
      id: "scummvm_drascula",
      name: "Drascula: The Vampire Strikes Back",
      tagline: dgettext_noop("arcade", "Comedic Dracula parody adventure (1996)"),
      description:
        dgettext_noop(
          "arcade",
          "British real estate agent John Hacker must defeat the vampire Drascula in this hilarious Spanish point & click adventure full of pop culture references and absurd humor."
        ),
      engine: :scummvm,
      controls:
        dgettext_noop(
          "arcade",
          "Point & click: left-click interact, right-click examine. Inventory at bottom of screen. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_drascula"
    },
    %{
      id: "scummvm_dreamweb",
      name: "Dreamweb",
      tagline: dgettext_noop("arcade", "Dark cyberpunk adventure (1994)"),
      description:
        dgettext_noop(
          "arcade",
          "A disturbing top-down cyberpunk adventure by Creative Reality. You are Ryan, plagued by nightmares about the Dreamweb — a mystical barrier protecting reality. Full CD version with voice acting."
        ),
      engine: :scummvm,
      controls:
        dgettext_noop(
          "arcade",
          "Point & click: left-click interact/walk, right-click examine. Inventory at top of screen. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_dreamweb"
    },
    %{
      id: "scummvm_fotaq",
      name: "Flight of the Amazon Queen",
      tagline: dgettext_noop("arcade", "Comic adventure in the Amazon (1995)"),
      description:
        dgettext_noop(
          "arcade",
          "Pilot Joe King crash-lands in the Amazon and stumbles into a mad scientist's plot to turn humans into dinosaurs. A hilarious Indiana Jones-style point & click adventure with full voice acting."
        ),
      engine: :scummvm,
      controls:
        dgettext_noop(
          "arcade",
          "Point & click: left-click interact, right-click examine. Inventory at top of screen. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_fotaq"
    },
    %{
      id: "scummvm_lure",
      name: "Lure of the Temptress",
      tagline: dgettext_noop("arcade", "Medieval fantasy adventure (1992)"),
      description:
        dgettext_noop(
          "arcade",
          "Free the village of Turnvale from the sorceress Selena. Revolution Software's debut game featuring the innovative Virtual Theatre system with autonomous NPCs."
        ),
      engine: :scummvm,
      controls:
        dgettext_noop(
          "arcade",
          "Point & click: left-click interact, right-click verb menu. NPCs follow their own schedules. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_lure"
    },
    %{
      id: "scummvm_soltys",
      name: "Soltys",
      tagline: dgettext_noop("arcade", "Surreal Polish puzzle adventure (1995)"),
      description:
        dgettext_noop(
          "arcade",
          "Rescue your grandfather from underground pirates in this charmingly absurd Polish point & click adventure full of creative puzzles and surreal humor."
        ),
      engine: :scummvm,
      controls:
        dgettext_noop(
          "arcade",
          "Point & click: left-click interact, right-click examine. Simple, streamlined interface. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_soltys"
    }
  ]

  # Each engine's own name — a proper noun, the same in every language — shown
  # on a game's sheet. Every engine here must sit on a shelf (checked below).
  @engines [
    doom: "DOOM",
    quake: "Quake",
    quake2: "Quake II",
    wolfenstein: "Wolf3D",
    halflife: "Half-Life",
    scummvm: "ScummVM"
  ]

  @doc "An engine's own name: `:quake2` is \"Quake II\"."
  @spec engine_name(atom()) :: String.t()
  def engine_name(engine), do: Keyword.fetch!(@engines, engine)

  # The shelf each game sits on, wherever the arcade is listed: the Arcade
  # folder, the Start menu, the public catalogue. A game's engine decides it,
  # so a new game lands on its shelf without a line here; a new engine must
  # be given one (checked below).
  @categories [
    fps:
      {dpgettext_noop("arcade", "game category", "First-Person Shooters"),
       [:doom, :quake, :quake2, :wolfenstein, :halflife]},
    adventure: {dpgettext_noop("arcade", "game category", "Adventures"), [:scummvm]}
  ]

  shelved = for {_category, {_name, engines}} <- @categories, engine <- engines, do: engine

  for engine <- Keyword.keys(@engines), Enum.count(shelved, &(&1 == engine)) != 1 do
    raise CompileError, description: "engine #{engine} needs exactly one category"
  end

  @type category :: :fps | :adventure

  @doc "Every category, in the order the catalogue shows them."
  @spec categories() :: [category()]
  def categories, do: Keyword.keys(@categories)

  @doc "A category's name, in the reader's language."
  @spec category_name(category()) :: String.t()
  def category_name(category) do
    {name, _engines} = Keyword.fetch!(@categories, category)
    Gettext.dpgettext(RetroHexChat.Gettext, "arcade", "game category", name)
  end

  @doc "The category a game's engine puts it in."
  @spec category(game()) :: category()
  def category(%{engine: engine}) do
    Enum.find_value(@categories, fn {category, {_name, engines}} ->
      engine in engines and category
    end)
  end

  # ex_dna:disable-for-lines:29 two catalogues, one lookup API each over its own @games
  @spec list_games() :: [game()]
  def list_games, do: Enum.map(@games, &translate_game/1)

  @spec get_game(String.t()) :: {:ok, game()} | {:error, :not_found}
  def get_game(id) do
    case Enum.find(@games, &(&1.id == id)) do
      nil -> {:error, :not_found}
      game -> {:ok, translate_game(game)}
    end
  end

  @doc "A game's name, or its id when the catalogue no longer has it."
  @spec game_name(String.t()) :: String.t()
  def game_name(id) do
    case get_game(id) do
      {:ok, game} -> game.name
      {:error, :not_found} -> id
    end
  end

  @spec valid_game_id?(String.t()) :: boolean()
  def valid_game_id?(id), do: Enum.any?(@games, &(&1.id == id))

  @spec game_ids() :: [String.t()]
  def game_ids, do: Enum.map(@games, & &1.id)

  @doc "The box-art name of a game (`game_doom`), or nil for an id not in the catalogue."
  @spec icon(String.t()) :: String.t() | nil
  def icon(id), do: Enum.find_value(@games, &(&1.id == id and &1.icon))

  @doc """
  The address-safe name of a game: `"doom-shareware"` for `"doom_shareware"`.
  Its public page and its channel are both named after it.
  """
  @spec slug(String.t()) :: String.t()
  def slug(game_id), do: String.replace(game_id, "_", "-")

  @doc "The channel where `game_id` is talked about and its plays are announced: `#doom-shareware`."
  @spec channel_name(String.t()) :: String.t()
  def channel_name(game_id), do: "#" <> slug(game_id)

  @doc "The channel every arcade game's plays are also announced in."
  @spec feed_channel() :: String.t()
  def feed_channel, do: "#arcade"

  @doc "Every game's channel, in catalogue order."
  @spec channel_names() :: [String.t()]
  def channel_names, do: Enum.map(@games, &channel_name(&1.id))

  @doc "The game a channel belongs to; `:error` for any other channel."
  @spec game_for_channel(String.t()) :: {:ok, String.t()} | :error
  def game_for_channel("#" <> name) do
    case Enum.find(@games, &(slug(&1.id) == String.downcase(name))) do
      %{id: id} -> {:ok, id}
      nil -> :error
    end
  end

  def game_for_channel(_name), do: :error

  # ScummVM game ID → directory and ScummVM gameid mapping for URL fragment auto-start
  @scummvm_games %{
    "scummvm_bass" => {"bass", "sky"},
    "scummvm_fotaq" => {"fotaq", "queen"},
    "scummvm_lure" => {"lure", "lure"},
    "scummvm_drascula" => {"drascula", "drascula"},
    "scummvm_dreamweb" => {"dreamweb", "dreamweb"},
    "scummvm_soltys" => {"soltys", "soltys"}
  }

  @spec game_url(game()) :: String.t()
  def game_url(%{id: id, engine: :scummvm}) do
    {dir, gameid} = Map.fetch!(@scummvm_games, id)
    "#{arcade_base_url()}/scummvm/index.html#-p /data/games/#{dir}/ #{gameid}"
  end

  def game_url(%{id: id}), do: "#{arcade_base_url()}/#{id}/index.html"

  defp translate_game(game), do: CatalogText.translate(game, "arcade")

  defp arcade_base_url, do: Application.fetch_env!(:retro_hex_chat, :arcade_base_url)
end

defmodule RetroHexChat.Arcade.Catalog do
  @moduledoc """
  Registry of available single-player arcade games.
  Each game maps to a WASM engine (Doom via Dwasm, Quake via Qwasm) with specific game data.
  """

  use Gettext, backend: RetroHexChat.Gettext

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
      name: gettext_noop("DOOM: Knee-Deep in the Dead"),
      tagline: gettext_noop("Episode 1 — The Original"),
      description:
        gettext_noop(
          "The original Episode 1 of DOOM (1993) — 9 levels of demon-infested corridors on Phobos. The shareware classic that started it all."
        ),
      engine: :doom,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_doom"
    },
    %{
      id: "freedoom1",
      name: gettext_noop("Freedoom: Phase 1"),
      tagline: gettext_noop("36 levels of open-source doom"),
      description:
        gettext_noop(
          "A complete free replacement for Ultimate DOOM — 4 episodes, 36 levels. Original art, music, and levels under BSD license."
        ),
      engine: :doom,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_freedoom1"
    },
    %{
      id: "freedoom2",
      name: gettext_noop("Freedoom: Phase 2"),
      tagline: gettext_noop("32 levels — Doom II compatible"),
      description:
        gettext_noop(
          "A complete free replacement for DOOM II — 32 levels with the Super Shotgun. Compatible with thousands of community-made PWAD mods."
        ),
      engine: :doom,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_freedoom2"
    },
    %{
      id: "freedm",
      name: gettext_noop("FreeDM"),
      tagline: gettext_noop("Deathmatch arena — open source"),
      description:
        gettext_noop(
          "Free deathmatch-focused maps for DOOM. 32 arena-style levels designed for fast-paced multiplayer action. BSD license."
        ),
      engine: :doom,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_freedm"
    },
    %{
      id: "chex_quest",
      name: gettext_noop("Chex Quest"),
      tagline: gettext_noop("The cereal box classic"),
      description:
        gettext_noop(
          "The legendary 1996 cereal box promotion — a kid-friendly total conversion of DOOM where you zap Flemoids with the Zorcher. 5 levels of nostalgia."
        ),
      engine: :doom,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_chex"
    },
    %{
      id: "hacx",
      name: gettext_noop("HacX: Twitch 'n Kill"),
      tagline: gettext_noop("Cyberpunk total conversion"),
      description:
        gettext_noop(
          "A cyberpunk total conversion — hack through a dystopian future with new weapons, enemies, and levels. Standalone v1.2 IWAD."
        ),
      engine: :doom,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_hacx"
    },
    %{
      id: "rekkr",
      name: gettext_noop("REKKR: Sunken Land"),
      tagline: gettext_noop("Viking-themed standalone"),
      description:
        gettext_noop(
          "A Viking-themed total conversion with hand-drawn pixel art. Battle through Norse-inspired levels with axes, bows, and runic magic."
        ),
      engine: :doom,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use, Space jump"),
      icon: "game_rekkr"
    },
    %{
      id: "quake_shareware",
      name: gettext_noop("Quake: Dimension of the Doomed"),
      tagline: gettext_noop("Episode 1 — The Original"),
      description:
        gettext_noop(
          "The original Episode 1 of Quake (1996) — full 3D FPS with Lovecraftian horrors. The shareware episode that pushed PC gaming into true 3D."
        ),
      engine: :quake,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use"),
      icon: "game_quake"
    },
    %{
      id: "librequake",
      name: gettext_noop("LibreQuake"),
      tagline: gettext_noop("Open-source Quake replacement"),
      description:
        gettext_noop(
          "A complete free replacement for Quake — original levels, art, and music under BSD license. Community-made open-source content."
        ),
      engine: :quake,
      controls: gettext_noop("WASD move, Mouse aim, Left click fire, E use"),
      icon: "game_librequake"
    },
    %{
      id: "quake2_shareware",
      name: gettext_noop("Quake II: The Invasion"),
      tagline: gettext_noop("Unit 1 — The Demo"),
      description:
        gettext_noop(
          "The official Quake II demo (1997) — full 3D FPS with Strogg invasion. Unit 1 of the singleplayer campaign. The shareware classic that defined online FPS."
        ),
      engine: :quake2,
      controls:
        gettext_noop(
          "WASD move, Mouse aim, Left click fire, E use, Space jump, C crouch, R reload"
        ),
      icon: "game_quake2"
    },
    %{
      id: "wolfenstein_3d",
      name: gettext_noop("Wolfenstein 3D: Escape from Castle"),
      tagline: gettext_noop("Episode 1 — The Shareware Classic"),
      description:
        gettext_noop(
          "The grandfather of FPS games (1992) — 10 levels of castle-storming action. The shareware episode that launched the first-person shooter genre."
        ),
      engine: :wolfenstein,
      controls:
        gettext_noop("Arrow keys move, Ctrl fire, Space open doors, Shift run, 1-4 weapons"),
      icon: "game_wolfenstein"
    },
    %{
      id: "halflife_uplink",
      name: gettext_noop("Half-Life: Uplink"),
      tagline: gettext_noop("The Official Demo — 3 Unique Missions"),
      description:
        gettext_noop(
          "The official Half-Life demo (1999) — 3 unique levels not found in the full game. Fight through Black Mesa's underground labs. Freely redistributable by Valve."
        ),
      engine: :halflife,
      controls:
        gettext_noop(
          "WASD move, Mouse aim, Left click fire, E use, Space jump, Shift crouch, R reload"
        ),
      icon: "game_halflife"
    },
    %{
      id: "scummvm_bass",
      name: gettext_noop("Beneath a Steel Sky"),
      tagline: gettext_noop("Cyberpunk point & click adventure (1994)"),
      description:
        gettext_noop(
          "Escape Union City and uncover your past in this cyberpunk classic by Revolution Software. One of the greatest point & click adventures ever made."
        ),
      engine: :scummvm,
      controls:
        gettext_noop(
          "Left click interact/walk, Right click examine/verb menu, Drag inventory items to combine. F5 save/load, Ctrl+F5 options, Esc skip cutscene"
        ),
      icon: "game_bass"
    },
    %{
      id: "scummvm_drascula",
      name: gettext_noop("Drascula: The Vampire Strikes Back"),
      tagline: gettext_noop("Comedic Dracula parody adventure (1996)"),
      description:
        gettext_noop(
          "British real estate agent John Hacker must defeat the vampire Drascula in this hilarious Spanish point & click adventure full of pop culture references and absurd humor."
        ),
      engine: :scummvm,
      controls:
        gettext_noop(
          "Point & click: left-click interact, right-click examine. Inventory at bottom of screen. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_drascula"
    },
    %{
      id: "scummvm_dreamweb",
      name: gettext_noop("Dreamweb"),
      tagline: gettext_noop("Dark cyberpunk adventure (1994)"),
      description:
        gettext_noop(
          "A disturbing top-down cyberpunk adventure by Creative Reality. You are Ryan, plagued by nightmares about the Dreamweb — a mystical barrier protecting reality. Full CD version with voice acting."
        ),
      engine: :scummvm,
      controls:
        gettext_noop(
          "Point & click: left-click interact/walk, right-click examine. Inventory at top of screen. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_dreamweb"
    },
    %{
      id: "scummvm_fotaq",
      name: gettext_noop("Flight of the Amazon Queen"),
      tagline: gettext_noop("Comic adventure in the Amazon (1995)"),
      description:
        gettext_noop(
          "Pilot Joe King crash-lands in the Amazon and stumbles into a mad scientist's plot to turn humans into dinosaurs. A hilarious Indiana Jones-style point & click adventure with full voice acting."
        ),
      engine: :scummvm,
      controls:
        gettext_noop(
          "Point & click: left-click interact, right-click examine. Inventory at top of screen. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_fotaq"
    },
    %{
      id: "scummvm_lure",
      name: gettext_noop("Lure of the Temptress"),
      tagline: gettext_noop("Medieval fantasy adventure (1992)"),
      description:
        gettext_noop(
          "Free the village of Turnvale from the sorceress Selena. Revolution Software's debut game featuring the innovative Virtual Theatre system with autonomous NPCs."
        ),
      engine: :scummvm,
      controls:
        gettext_noop(
          "Point & click: left-click interact, right-click verb menu. NPCs follow their own schedules. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_lure"
    },
    %{
      id: "scummvm_soltys",
      name: gettext_noop("Soltys"),
      tagline: gettext_noop("Surreal Polish puzzle adventure (1995)"),
      description:
        gettext_noop(
          "Rescue your grandfather from underground pirates in this charmingly absurd Polish point & click adventure full of creative puzzles and surreal humor."
        ),
      engine: :scummvm,
      controls:
        gettext_noop(
          "Point & click: left-click interact, right-click examine. Simple, streamlined interface. F5 save/load, Esc skip cutscene"
        ),
      icon: "game_soltys"
    }
  ]

  @spec list_games() :: [game()]
  def list_games, do: Enum.map(@games, &translate_game/1)

  @spec get_game(String.t()) :: {:ok, game()} | {:error, :not_found}
  def get_game(id) do
    case Enum.find(@games, &(&1.id == id)) do
      nil -> {:error, :not_found}
      game -> {:ok, translate_game(game)}
    end
  end

  @spec valid_game_id?(String.t()) :: boolean()
  def valid_game_id?(id), do: Enum.any?(@games, &(&1.id == id))

  @spec game_ids() :: [String.t()]
  def game_ids, do: Enum.map(@games, & &1.id)

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

  defp translate_game(game) do
    game
    |> Map.update!(:name, &t/1)
    |> Map.update!(:tagline, &t/1)
    |> Map.update!(:description, &t/1)
    |> Map.update!(:controls, &t/1)
  end

  defp t(msgid), do: Gettext.gettext(RetroHexChat.Gettext, msgid)

  defp arcade_base_url, do: Application.fetch_env!(:retro_hex_chat, :arcade_base_url)
end

defmodule RetroHexChat.Arcade.Catalog do
  @moduledoc """
  Registry of available single-player arcade games.
  Each game maps to a WASM engine (Doom via Dwasm, Quake via Qwasm) with specific game data.
  """

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
      tagline: "Episode 1 — The Original",
      description:
        "The original Episode 1 of DOOM (1993) — 9 levels of demon-infested " <>
          "corridors on Phobos. The shareware classic that started it all.",
      engine: :doom,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump",
      icon: "game_doom"
    },
    %{
      id: "freedoom1",
      name: "Freedoom: Phase 1",
      tagline: "36 levels of open-source doom",
      description:
        "A complete free replacement for Ultimate DOOM — 4 episodes, 36 levels. " <>
          "Original art, music, and levels under BSD license.",
      engine: :doom,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump",
      icon: "game_freedoom1"
    },
    %{
      id: "freedoom2",
      name: "Freedoom: Phase 2",
      tagline: "32 levels — Doom II compatible",
      description:
        "A complete free replacement for DOOM II — 32 levels with the Super Shotgun. " <>
          "Compatible with thousands of community-made PWAD mods.",
      engine: :doom,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump",
      icon: "game_freedoom2"
    },
    %{
      id: "freedm",
      name: "FreeDM",
      tagline: "Deathmatch arena — open source",
      description:
        "Free deathmatch-focused maps for DOOM. 32 arena-style levels designed " <>
          "for fast-paced multiplayer action. BSD license.",
      engine: :doom,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump",
      icon: "game_freedm"
    },
    %{
      id: "chex_quest",
      name: "Chex Quest",
      tagline: "The cereal box classic",
      description:
        "The legendary 1996 cereal box promotion — a kid-friendly total conversion " <>
          "of DOOM where you zap Flemoids with the Zorcher. 5 levels of nostalgia.",
      engine: :doom,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump",
      icon: "game_chex"
    },
    %{
      id: "hacx",
      name: "HacX: Twitch 'n Kill",
      tagline: "Cyberpunk total conversion",
      description:
        "A cyberpunk total conversion — hack through a dystopian future with " <>
          "new weapons, enemies, and levels. Standalone v1.2 IWAD.",
      engine: :doom,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump",
      icon: "game_hacx"
    },
    %{
      id: "rekkr",
      name: "REKKR: Sunken Land",
      tagline: "Viking-themed standalone",
      description:
        "A Viking-themed total conversion with hand-drawn pixel art. " <>
          "Battle through Norse-inspired levels with axes, bows, and runic magic.",
      engine: :doom,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump",
      icon: "game_rekkr"
    },
    %{
      id: "quake_shareware",
      name: "Quake: Dimension of the Doomed",
      tagline: "Episode 1 — The Original",
      description:
        "The original Episode 1 of Quake (1996) — full 3D FPS with Lovecraftian horrors. " <>
          "The shareware episode that pushed PC gaming into true 3D.",
      engine: :quake,
      controls: "WASD move, Mouse aim, Left click fire, E use",
      icon: "game_quake"
    },
    %{
      id: "librequake",
      name: "LibreQuake",
      tagline: "Open-source Quake replacement",
      description:
        "A complete free replacement for Quake — original levels, art, and music " <>
          "under BSD license. Community-made open-source content.",
      engine: :quake,
      controls: "WASD move, Mouse aim, Left click fire, E use",
      icon: "game_librequake"
    },
    %{
      id: "quake2_shareware",
      name: "Quake II: The Invasion",
      tagline: "Unit 1 — The Demo",
      description:
        "The official Quake II demo (1997) — full 3D FPS with Strogg invasion. " <>
          "Unit 1 of the singleplayer campaign. The shareware classic that defined online FPS.",
      engine: :quake2,
      controls: "WASD move, Mouse aim, Left click fire, E use, Space jump, C crouch, R reload",
      icon: "game_quake2"
    },
    %{
      id: "wolfenstein_3d",
      name: "Wolfenstein 3D: Escape from Castle",
      tagline: "Episode 1 — The Shareware Classic",
      description:
        "The grandfather of FPS games (1992) — 10 levels of castle-storming action. " <>
          "The shareware episode that launched the first-person shooter genre.",
      engine: :wolfenstein,
      controls: "Arrow keys move, Ctrl fire, Space open doors, Shift run, 1-4 weapons",
      icon: "game_wolfenstein"
    },
    %{
      id: "halflife_uplink",
      name: "Half-Life: Uplink",
      tagline: "The Official Demo — 3 Unique Missions",
      description:
        "The official Half-Life demo (1999) — 3 unique levels not found in the full game. " <>
          "Fight through Black Mesa's underground labs. Freely redistributable by Valve.",
      engine: :halflife,
      controls:
        "WASD move, Mouse aim, Left click fire, E use, Space jump, Shift crouch, R reload",
      icon: "game_halflife"
    },
    %{
      id: "scummvm_bass",
      name: "Beneath a Steel Sky",
      tagline: "Cyberpunk point & click adventure (1994)",
      description:
        "Escape Union City and uncover your past in this cyberpunk classic by " <>
          "Revolution Software. One of the greatest point & click adventures ever made.",
      engine: :scummvm,
      controls:
        "Left click interact/walk, Right click examine/verb menu, " <>
          "Drag inventory items to combine. F5 save/load, Ctrl+F5 options, Esc skip cutscene",
      icon: "game_bass"
    },
    %{
      id: "scummvm_drascula",
      name: "Drascula: The Vampire Strikes Back",
      tagline: "Comedic Dracula parody adventure (1996)",
      description:
        "British real estate agent John Hacker must defeat the vampire Drascula " <>
          "in this hilarious Spanish point & click adventure full of pop culture " <>
          "references and absurd humor.",
      engine: :scummvm,
      controls:
        "Point & click: left-click interact, right-click examine. " <>
          "Inventory at bottom of screen. F5 save/load, Esc skip cutscene",
      icon: "game_drascula"
    },
    %{
      id: "scummvm_dreamweb",
      name: "Dreamweb",
      tagline: "Dark cyberpunk adventure (1994)",
      description:
        "A disturbing top-down cyberpunk adventure by Creative Reality. " <>
          "You are Ryan, plagued by nightmares about the Dreamweb — a mystical barrier " <>
          "protecting reality. Full CD version with voice acting.",
      engine: :scummvm,
      controls:
        "Point & click: left-click interact/walk, right-click examine. " <>
          "Inventory at top of screen. F5 save/load, Esc skip cutscene",
      icon: "game_dreamweb"
    },
    %{
      id: "scummvm_fotaq",
      name: "Flight of the Amazon Queen",
      tagline: "Comic adventure in the Amazon (1995)",
      description:
        "Pilot Joe King crash-lands in the Amazon and stumbles into a mad scientist's " <>
          "plot to turn humans into dinosaurs. A hilarious Indiana Jones-style " <>
          "point & click adventure with full voice acting.",
      engine: :scummvm,
      controls:
        "Point & click: left-click interact, right-click examine. " <>
          "Inventory at top of screen. F5 save/load, Esc skip cutscene",
      icon: "game_fotaq"
    }
  ]

  @spec list_games() :: [game()]
  def list_games, do: @games

  @spec get_game(String.t()) :: {:ok, game()} | {:error, :not_found}
  def get_game(id) do
    case Enum.find(@games, &(&1.id == id)) do
      nil -> {:error, :not_found}
      game -> {:ok, game}
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
    "/arcade/scummvm/index.html#-p /data/games/#{dir}/ #{gameid}"
  end

  def game_url(%{id: id}), do: "/arcade/#{id}/index.html"
end

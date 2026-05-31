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
      name: dgettext_noop("arcade", "DOOM: Knee-Deep in the Dead"),
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
      name: dgettext_noop("arcade", "Freedoom: Phase 1"),
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
      name: dgettext_noop("arcade", "Freedoom: Phase 2"),
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
      name: dgettext_noop("arcade", "FreeDM"),
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
      name: dgettext_noop("arcade", "Chex Quest"),
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
      name: dgettext_noop("arcade", "HacX: Twitch 'n Kill"),
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
      name: dgettext_noop("arcade", "REKKR: Sunken Land"),
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
      name: dgettext_noop("arcade", "Quake: Dimension of the Doomed"),
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
      name: dgettext_noop("arcade", "LibreQuake"),
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
      name: dgettext_noop("arcade", "Quake II: The Invasion"),
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
      name: dgettext_noop("arcade", "Wolfenstein 3D: Escape from Castle"),
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
      name: dgettext_noop("arcade", "Half-Life: Uplink"),
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
      name: dgettext_noop("arcade", "Beneath a Steel Sky"),
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
      name: dgettext_noop("arcade", "Drascula: The Vampire Strikes Back"),
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
      name: dgettext_noop("arcade", "Dreamweb"),
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
      name: dgettext_noop("arcade", "Flight of the Amazon Queen"),
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
      name: dgettext_noop("arcade", "Lure of the Temptress"),
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
      name: dgettext_noop("arcade", "Soltys"),
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

  defp t(msgid), do: Gettext.dgettext(RetroHexChat.Gettext, "arcade", msgid)

  defp arcade_base_url, do: Application.fetch_env!(:retro_hex_chat, :arcade_base_url)
end

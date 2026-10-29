defmodule RetroHexChat.Games.Catalog do
  @moduledoc """
  Registry of available real-time browser games.
  Each game has an id, name, description, and icon identifier.
  """

  use Gettext, backend: RetroHexChat.Gettext

  alias RetroHexChat.CatalogText

  @solo_game_ids [
    "hex_pong",
    "light_trails",
    "pixel_tanks",
    "star_duel",
    "gravity_well",
    "debris_field",
    "block_breakers",
    "hex_warlords",
    "hex_raid",
    "hex_raid_pacifist",
    "hex_raid_blitz",
    "hex_boxing",
    "hex_outlaw",
    "hex_outlaw_ricochet",
    "hex_outlaw_stagecoach",
    "hex_outlaw_nml",
    "hex_invaders",
    "hex_invaders_coop",
    "hex_invaders_blitz",
    "hex_enduro",
    "hex_enduro_night",
    "hex_enduro_sprint",
    "hex_tennis",
    "hex_tennis_quick",
    "hex_tennis_sudden",
    "hex_skiing",
    "hex_skiing_escape",
    "hex_skiing_clean",
    "hex_frost",
    "hex_frost_blizzard",
    "hex_frost_peaceful",
    "hex_hockey",
    "hex_hockey_blitz",
    "hex_hockey_showdown",
    "hex_jungle",
    "hex_solitaire",
    "hex_solitaire_draw3",
    "hex_freecell",
    "hex_spider",
    "hex_spider_2suits",
    "hex_spider_4suits",
    "hex_mines",
    "hex_mines_intermediate",
    "hex_mines_expert",
    "hex_sudoku",
    "hex_sudoku_medium",
    "hex_sudoku_hard",
    "hex_blocks",
    "hex_blocks_sprint"
  ]

  # Played by one person alone: no opponent, no partner, nothing to watch. A
  # one-player game is also played solo and ranked by score (checked below).
  @solo_only_game_ids ~w(hex_jungle hex_solitaire hex_solitaire_draw3 hex_freecell hex_spider
                         hex_spider_2suits hex_spider_4suits hex_mines hex_mines_intermediate
                         hex_mines_expert hex_sudoku hex_sudoku_medium hex_sudoku_hard hex_blocks
                         hex_blocks_sprint)

  # How a finished match is ranked. Versus games have two sides and one winner;
  # score games rank the points a player took home; co-op games rank the score
  # the pair made together. Every game sits in exactly one list: compilation
  # stops on a game left out, since a score game ranked as versus would have its
  # real results refused as implausible.
  @versus_game_ids ~w(hex_pong light_trails pixel_tanks star_duel gravity_well debris_field
                      hex_warlords hex_boxing hex_outlaw hex_outlaw_ricochet hex_outlaw_stagecoach
                      hex_outlaw_nml hex_tennis hex_tennis_quick hex_tennis_sudden hex_skiing
                      hex_skiing_escape hex_skiing_clean hex_frost hex_frost_blizzard
                      hex_frost_peaceful hex_hockey hex_hockey_blitz hex_hockey_showdown)
  @score_game_ids ~w(hex_raid hex_raid_pacifist hex_raid_blitz hex_invaders hex_invaders_blitz
                     hex_enduro hex_enduro_night hex_enduro_sprint hex_jungle hex_solitaire
                     hex_solitaire_draw3 hex_freecell hex_spider hex_spider_2suits
                     hex_spider_4suits hex_mines hex_mines_intermediate hex_mines_expert
                     hex_sudoku hex_sudoku_medium hex_sudoku_hard hex_blocks hex_blocks_sprint)
  @coop_game_ids ~w(block_breakers hex_invaders_coop)

  @type ranking :: :versus | :score | :coop

  @type game :: %{
          required(:id) => String.t(),
          optional(:mode_of) => String.t(),
          required(:name) => String.t(),
          required(:tagline) => String.t(),
          required(:description) => String.t(),
          required(:icon) => String.t(),
          required(:controls) => String.t()
        }

  @games [
    %{
      id: "hex_pong",
      name: "Hex Pong",
      tagline: dgettext_noop("games", "Cyberpunk Pong"),
      description:
        dgettext_noop(
          "games",
          "Pong reimagined as cyberpunk arcade — neon glow, CRT scanlines, synth audio. First to 11 points (win by 2). Ball speeds up on each rally."
        ),
      icon: "game_pong",
      controls: dgettext_noop("games", "Arrow keys or W/S to move paddle")
    },
    %{
      id: "light_trails",
      name: "Light Trails",
      tagline: dgettext_noop("games", "Don't cross the line"),
      description:
        dgettext_noop(
          "games",
          "Race across a grid arena leaving a glowing trail behind you. Hit a trail or the wall and you're out. Trap your opponent to win."
        ),
      icon: "game_trails",
      controls: dgettext_noop("games", "Arrow keys to change direction")
    },
    %{
      id: "pixel_tanks",
      name: "Pixel Tanks",
      tagline: dgettext_noop("games", "Blast through the maze"),
      description:
        dgettext_noop(
          "games",
          "Top-down tank combat in a maze. Shots bounce off the first wall they hit — use geometry to your advantage."
        ),
      icon: "game_tanks",
      controls:
        dgettext_noop("games", "Arrow keys (Left/Right rotate, Up forward), Space to fire")
    },
    %{
      id: "star_duel",
      name: "Star Duel",
      tagline: dgettext_noop("games", "Dogfight in the void"),
      description:
        dgettext_noop(
          "games",
          "Newtonian space combat — thrust, rotate, and fire missiles in open vacuum. Wraparound edges, hyperspace warp (20% death chance), first to 7 wins."
        ),
      icon: "game_space",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
        )
    },
    %{
      id: "gravity_well",
      name: "Gravity Well",
      tagline: dgettext_noop("games", "Orbit the dying star"),
      description:
        dgettext_noop(
          "games",
          "Orbital combat around a central gravity star. Use gravity slingshots, but fly too close and the star kills you. First to 7 wins."
        ),
      icon: "game_gravity",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
        )
    },
    %{
      id: "debris_field",
      name: "Debris Field",
      tagline: dgettext_noop("games", "Navigate the wreckage"),
      description:
        dgettext_noop(
          "games",
          "Fight through a field of floating asteroids that block missiles and kill on contact. Use the debris for cover — or watch it destroy you. First to 7 wins."
        ),
      icon: "game_debris",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys or WASD to thrust/rotate, Space to fire, Down/S to warp"
        )
    },
    %{
      id: "block_breakers",
      name: "Block Breakers",
      tagline: dgettext_noop("games", "Break blocks together"),
      description:
        dgettext_noop(
          "games",
          "Cooperative Breakout with two paddles — one at the top, one at the bottom. Work together to destroy all blocks before running out of lives."
        ),
      icon: "game_breakout",
      controls: dgettext_noop("games", "Arrow keys (Left/Right) to move paddle")
    },
    %{
      id: "hex_warlords",
      name: "Hex Warlords",
      tagline: dgettext_noop("games", "Defend your castle"),
      description:
        dgettext_noop(
          "games",
          "Versus Breakout battle — each player defends a brick castle with a king inside. Deflect or catch the fireball to smash your opponent's walls. Last king standing wins."
        ),
      icon: "game_warlords",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys (Up/Down) to move shield, Space to catch/release fireball"
        )
    },
    %{
      id: "hex_raid",
      name: "Hex Raid",
      tagline: dgettext_noop("games", "Two pilots, one river"),
      description:
        dgettext_noop(
          "games",
          "River Raid reimagined for two — race through a scrolling toxic canal, destroy enemies, steal fuel, and drop mines into your rival's path. The river narrows the farther you fly."
        ),
      icon: "game_raid",
      controls:
        dgettext_noop("games", "Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_raid_pacifist",
      mode_of: "hex_raid",
      name: "Hex Raid: Pacifist",
      tagline: dgettext_noop("games", "No mines, pure skill"),
      description:
        dgettext_noop(
          "games",
          "River Raid without sabotage — no mines allowed. Pure competition for points, fuel, and survival."
        ),
      icon: "game_raid",
      controls: dgettext_noop("games", "Arrow keys to move/speed, Space to fire")
    },
    %{
      id: "hex_raid_blitz",
      mode_of: "hex_raid",
      name: "Hex Raid: Blitz",
      tagline: dgettext_noop("games", "Fast and furious"),
      description:
        dgettext_noop(
          "games",
          "Intense River Raid action — the river starts narrow, fuel is scarce, mines recharge faster. Quick and chaotic."
        ),
      icon: "game_raid",
      controls:
        dgettext_noop("games", "Arrow keys to move/speed, Space to fire, Shift to drop mine")
    },
    %{
      id: "hex_boxing",
      name: "Hex Boxing",
      tagline: dgettext_noop("games", "Fists of fury"),
      description:
        dgettext_noop(
          "games",
          "Top-down boxing — close punches score more. Push-and-pull until KO or decision by points. Best of 3 rounds."
        ),
      icon: "game_boxing",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to punch")
    },
    %{
      id: "hex_outlaw",
      name: "Hex Outlaw",
      tagline: dgettext_noop("games", "Draw at high noon"),
      description:
        dgettext_noop(
          "games",
          "Western duel — two gunslingers and a cactus. Dodge bullets you can see coming. First to 10. Best of 3 rounds."
        ),
      icon: "game_outlaw",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_ricochet",
      mode_of: "hex_outlaw",
      name: "Hex Outlaw: Ricochet",
      tagline: dgettext_noop("games", "Bullets bounce back"),
      description:
        dgettext_noop(
          "games",
          "Western duel with bouncing bullets — fire at angles to bypass the wall. Bullets ricochet once off ceiling/floor. First to 10. Best of 3 rounds."
        ),
      icon: "game_outlaw",
      controls: dgettext_noop("games", "Arrow keys or WASD to move/aim, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_stagecoach",
      mode_of: "hex_outlaw",
      name: "Hex Outlaw: Stagecoach",
      tagline: dgettext_noop("games", "Moving cover"),
      description:
        dgettext_noop(
          "games",
          "Western duel with a stagecoach rolling across the arena. Time your shots around the moving obstacle. First to 10. Best of 3 rounds."
        ),
      icon: "game_outlaw",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_outlaw_nml",
      mode_of: "hex_outlaw",
      name: "Hex Outlaw: No Man's Land",
      tagline: dgettext_noop("games", "Nowhere to hide"),
      description:
        dgettext_noop(
          "games",
          "Western duel in open field — no obstacle, full horizontal movement. Dodge freely in your half. First to 10. Best of 3 rounds."
        ),
      icon: "game_outlaw",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to fire")
    },
    %{
      id: "hex_invaders",
      name: "Hex Invaders",
      tagline: dgettext_noop("games", "Your kills are their problem"),
      description:
        dgettext_noop(
          "games",
          "Split-screen Space Invaders — aliens you destroy fall on your opponent as reinforcements. Combos send extra. 10 waves of escalating chaos."
        ),
      icon: "game_invaders",
      controls: dgettext_noop("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_coop",
      mode_of: "hex_invaders",
      name: "Hex Invaders: Co-op",
      tagline: dgettext_noop("games", "Defend Earth together"),
      description:
        dgettext_noop(
          "games",
          "Classic co-op Space Invaders — two cannons fighting the same alien waves. No alien drop. Survive together or fall together."
        ),
      icon: "game_invaders",
      controls: dgettext_noop("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_invaders_blitz",
      mode_of: "hex_invaders",
      name: "Hex Invaders: Blitz",
      tagline: dgettext_noop("games", "No mercy, no delay"),
      description:
        dgettext_noop(
          "games",
          "Blitz Space Invaders — instant alien drops, easier combos, 5 waves of pure chaos from the start."
        ),
      icon: "game_invaders",
      controls: dgettext_noop("games", "Arrow keys or A/D to move, Space to fire")
    },
    %{
      id: "hex_enduro",
      name: "Hex Enduro",
      tagline: dgettext_noop("games", "Race through the wasteland"),
      description:
        dgettext_noop(
          "games",
          "Pseudo-3D racing duel through day, snow, fog, and night. Overtake AI cars and your opponent, manage fuel, draft in slipstreams. Best of 3 days."
        ),
      icon: "game_enduro",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
        )
    },
    %{
      id: "hex_enduro_night",
      mode_of: "hex_enduro",
      name: "Hex Enduro: Night Race",
      tagline: dgettext_noop("games", "Headlights only"),
      description:
        dgettext_noop(
          "games",
          "3-minute race in permanent darkness with fog bursts. Pure reflexes — most overtakes wins. Headlights only visibility."
        ),
      icon: "game_enduro",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
        )
    },
    %{
      id: "hex_enduro_sprint",
      mode_of: "hex_enduro",
      name: "Hex Enduro: Sprint",
      tagline: dgettext_noop("games", "90 seconds of fury"),
      description:
        dgettext_noop(
          "games",
          "Daylight sprint — no weather changes, no fuel drain, just speed. 90 seconds to score maximum overtakes."
        ),
      icon: "game_enduro",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys (←/→ lane, ↑ accel, ↓ brake), Space or Shift for turbo"
        )
    },
    %{
      id: "hex_tennis",
      name: "Hex Tennis",
      tagline: dgettext_noop("games", "Serve, rally, win"),
      description:
        dgettext_noop(
          "games",
          "Top-down tennis duel — automatic hitting, shot angle depends on ball contact position. Full set with tiebreak at 6-6. Deuce, advantage, the works."
        ),
      icon: "game_tennis",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_quick",
      mode_of: "hex_tennis",
      name: "Hex Tennis: Quick Match",
      tagline: dgettext_noop("games", "First to 3 games"),
      description:
        dgettext_noop(
          "games",
          "Quick tennis match — first to 3 games wins. Same gameplay, shorter format. No tiebreak needed."
        ),
      icon: "game_tennis",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_tennis_sudden",
      mode_of: "hex_tennis",
      name: "Hex Tennis: Sudden Death",
      tagline: dgettext_noop("games", "One point, one game"),
      description:
        dgettext_noop(
          "games",
          "Every point wins a game — no 15-30-40, no deuce. First to 6 games takes the set. Pure pressure."
        ),
      icon: "game_tennis",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to serve")
    },
    %{
      id: "hex_skiing",
      name: "Hex Skiing",
      tagline: dgettext_noop("games", "Race the avalanche"),
      description:
        dgettext_noop(
          "games",
          "Top-down alpine descent through toxic wastelands — dodge mutant trees, clear slalom gates, outrun the avalanche. Best of 3 runs with rising difficulty."
        ),
      icon: "game_skiing",
      controls: dgettext_noop("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_escape",
      mode_of: "hex_skiing",
      name: "Hex Skiing: Escape",
      tagline: dgettext_noop("games", "Outrun the wasteland"),
      description:
        dgettext_noop(
          "games",
          "Infinite descent — the avalanche never stops accelerating. Last skier standing wins. Pure survival."
        ),
      icon: "game_skiing",
      controls: dgettext_noop("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_skiing_clean",
      mode_of: "hex_skiing",
      name: "Hex Skiing: Clean Run",
      tagline: dgettext_noop("games", "Pure downhill duel"),
      description:
        dgettext_noop(
          "games",
          "No avalanche, no items — just trees, rocks, and gates. Fastest time down the mountain wins."
        ),
      icon: "game_skiing",
      controls: dgettext_noop("games", "Arrow keys (←/→) or A/D to steer")
    },
    %{
      id: "hex_frost",
      name: "Hex Frost",
      tagline: dgettext_noop("games", "Build or be frozen"),
      description:
        dgettext_noop(
          "games",
          "Arctic construction race — jump on floating ice blocks to build your igloo. Steal your opponent's blocks for a 2-piece swing. Best of 5 rounds with polar bears, crabs, geese, and clams."
        ),
      icon: "game_frost",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_blizzard",
      mode_of: "hex_frost",
      name: "Hex Frost: Blizzard",
      tagline: dgettext_noop("games", "One epic round"),
      description:
        dgettext_noop(
          "games",
          "1 long round — 20-piece igloo, all enemies from the start, temperature drops slowly. Epic arctic endurance."
        ),
      icon: "game_frost",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_frost_peaceful",
      mode_of: "hex_frost",
      name: "Hex Frost: Peaceful",
      tagline: dgettext_noop("games", "No stealing, pure race"),
      description:
        dgettext_noop(
          "games",
          "Pure construction race — no block stealing allowed. First to complete the igloo wins. Fair and square."
        ),
      icon: "game_frost",
      controls: dgettext_noop("games", "Arrow keys or WASD to move, Up/Down to jump between rows")
    },
    %{
      id: "hex_hockey",
      name: "Hex Hockey",
      tagline: dgettext_noop("games", "Neon ice warfare"),
      description:
        dgettext_noop(
          "games",
          "Top-down ice hockey in a cyberpunk arena — control your field player, shoot, tackle, and score while your AI goalie defends. 3 periods of 2 minutes."
        ),
      icon: "game_hockey",
      controls:
        dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_blitz",
      mode_of: "hex_hockey",
      name: "Hex Hockey: Blitz",
      tagline: dgettext_noop("games", "Fast and brutal"),
      description:
        dgettext_noop(
          "games",
          "One period of 3 minutes — faster puck, higher tackle success rate. Pure intensity from start to finish."
        ),
      icon: "game_hockey",
      controls:
        dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_hockey_showdown",
      mode_of: "hex_hockey",
      name: "Hex Hockey: Showdown",
      tagline: dgettext_noop("games", "First to five"),
      description:
        dgettext_noop(
          "games",
          "No timer — first to 5 goals wins. Puck speed increases with each goal scored. The pressure builds every time the net shakes."
        ),
      icon: "game_hockey",
      controls:
        dgettext_noop("games", "Arrow keys or WASD to move, Space or Shift to shoot/tackle")
    },
    %{
      id: "hex_jungle",
      name: "Hex Jungle",
      tagline: dgettext_noop("games", "One adventurer, 255 screens"),
      description:
        dgettext_noop(
          "games",
          "Cross 255 screens of jungle and the tunnels below it. Jump over tree trunks and crocodiles, and find 32 treasures in twenty minutes."
        ),
      icon: "game_jungle",
      controls:
        dgettext_noop(
          "games",
          "Arrow keys or WASD to move and climb, the space bar to jump"
        )
    },
    %{
      id: "hex_solitaire",
      name: "Hex Solitaire",
      tagline: dgettext_noop("games", "Klondike solitaire, one card at a time"),
      description:
        dgettext_noop(
          "games",
          "Klondike solitaire: put every card on its pile, from the ace to the king, taking one card at a time from the deck. Win fast for a time bonus."
        ),
      icon: "game_solitaire",
      controls:
        dgettext_noop(
          "games",
          "Tap to play, or drag with the mouse or a finger"
        )
    },
    %{
      id: "hex_solitaire_draw3",
      mode_of: "hex_solitaire",
      name: "Hex Solitaire: Draw Three",
      tagline: dgettext_noop("games", "Three cards at a time"),
      description:
        dgettext_noop(
          "games",
          "Klondike taking three cards at a time from the deck, where only the top one can be played. More difficult, and closer to the classic game."
        ),
      icon: "game_solitaire",
      controls:
        dgettext_noop(
          "games",
          "Tap to play, or drag with the mouse or a finger"
        )
    },
    %{
      id: "hex_freecell",
      name: "Hex FreeCell",
      tagline: dgettext_noop("games", "All the cards face up, and four free cells"),
      description:
        dgettext_noop(
          "games",
          "FreeCell: all the cards are face up from the start. Use the four free cells to move cards, and put every card on its pile, from the ace to the king. Win fast for a time bonus."
        ),
      icon: "game_freecell",
      controls:
        dgettext_noop(
          "games",
          "Tap to play, or drag with the mouse or a finger"
        )
    },
    %{
      id: "hex_spider",
      name: "Hex Spider",
      tagline: dgettext_noop("games", "Two decks, ten columns, one suit"),
      description:
        dgettext_noop(
          "games",
          "Spider with one suit: build each suit from the king down to the ace in the ten columns, and a whole suit goes to its place by itself. Put away all eight to win."
        ),
      icon: "game_spider",
      controls:
        dgettext_noop(
          "games",
          "Tap to play, or drag with the mouse or a finger"
        )
    },
    %{
      id: "hex_spider_2suits",
      mode_of: "hex_spider",
      name: "Hex Spider: Two Suits",
      tagline: dgettext_noop("games", "Two suits: spades and hearts"),
      description:
        dgettext_noop(
          "games",
          "Spider with spades and hearts: only cards of the same suit move together, so plan where each suit goes."
        ),
      icon: "game_spider",
      controls:
        dgettext_noop(
          "games",
          "Tap to play, or drag with the mouse or a finger"
        )
    },
    %{
      id: "hex_spider_4suits",
      mode_of: "hex_spider",
      name: "Hex Spider: Four Suits",
      tagline: dgettext_noop("games", "All four suits: the hardest"),
      description:
        dgettext_noop(
          "games",
          "Spider with all four suits, the classic game at its hardest: few games are won, and every suit put away counts."
        ),
      icon: "game_spider",
      controls:
        dgettext_noop(
          "games",
          "Tap to play, or drag with the mouse or a finger"
        )
    },
    %{
      id: "hex_mines",
      name: "Hex Mines",
      tagline: dgettext_noop("games", "Minesweeper: 10 mines on a 9×9 field"),
      description:
        dgettext_noop(
          "games",
          "Minesweeper for beginners: open every square without a mine on a 9×9 field hiding 10. Each number tells how many mines touch it. The faster you clear the field, the more points."
        ),
      icon: "game_mines",
      controls:
        dgettext_noop(
          "games",
          "Click or tap to open a square; right click or long press to plant a flag"
        )
    },
    %{
      id: "hex_mines_intermediate",
      mode_of: "hex_mines",
      name: "Hex Mines: Intermediate",
      tagline: dgettext_noop("games", "40 mines on a 16×16 field"),
      description:
        dgettext_noop(
          "games",
          "Minesweeper on a 16×16 field hiding 40 mines: the classic middle level, where flags and chords start to save time."
        ),
      icon: "game_mines",
      controls:
        dgettext_noop(
          "games",
          "Click or tap to open a square; right click or long press to plant a flag"
        )
    },
    %{
      id: "hex_mines_expert",
      mode_of: "hex_mines",
      name: "Hex Mines: Expert",
      tagline: dgettext_noop("games", "99 mines on a 30×16 field"),
      description:
        dgettext_noop(
          "games",
          "Minesweeper at its hardest: 99 mines on a 30×16 field. On a phone the field stands up, sixteen squares across."
        ),
      icon: "game_mines",
      controls:
        dgettext_noop(
          "games",
          "Click or tap to open a square; right click or long press to plant a flag"
        )
    },
    %{
      id: "hex_sudoku",
      name: "Hex Sudoku",
      tagline: dgettext_noop("games", "Sudoku: a new 9×9 grid every game"),
      description:
        dgettext_noop(
          "games",
          "Sudoku for a quick game: fill the 9×9 grid so every row, column and box holds the digits 1 to 9 once. Each grid is new, with one solution you can reach without guessing. The faster you finish, the more points; a mistake or a hint adds time."
        ),
      icon: "game_sudoku",
      controls:
        dgettext_noop(
          "games",
          "Tap a square, then a digit; the pencil writes notes and the light bulb gives a hint"
        )
    },
    %{
      id: "hex_sudoku_medium",
      mode_of: "hex_sudoku",
      name: "Hex Sudoku: Medium",
      tagline: dgettext_noop("games", "Sudoku with fewer digits, for players who take notes"),
      description:
        dgettext_noop(
          "games",
          "Sudoku with fewer digits given: each grid needs a pair, a triple or a digit pointing out of a box before it opens up. This is where the notes start to help."
        ),
      icon: "game_sudoku",
      controls:
        dgettext_noop(
          "games",
          "Tap a square, then a digit; the pencil writes notes and the light bulb gives a hint"
        )
    },
    %{
      id: "hex_sudoku_hard",
      mode_of: "hex_sudoku",
      name: "Hex Sudoku: Hard",
      tagline: dgettext_noop("games", "Sudoku grids that need an X-Wing"),
      description:
        dgettext_noop(
          "games",
          "The hardest Sudoku here: every grid needs an X-Wing, a Swordfish or an XY-Wing somewhere, and none needs a guess."
        ),
      icon: "game_sudoku",
      controls:
        dgettext_noop(
          "games",
          "Tap a square, then a digit; the pencil writes notes and the light bulb gives a hint"
        )
    },
    %{
      id: "hex_blocks",
      name: "Hex Blocks",
      tagline: dgettext_noop("games", "Hexagon pieces falling into a honeycomb"),
      description:
        dgettext_noop(
          "games",
          "Each piece is made of hexagons and falls into a well. Turn the piece and slide it left or right as it falls. When a zigzag row is full, it disappears. Every ten rows, the pieces fall faster. You can save a piece for later and see the next three pieces."
        ),
      icon: "game_blocks",
      controls:
        dgettext_noop(
          "games",
          "Move and turn a piece with the arrow keys, and press the space bar to drop it. On a phone, tap the buttons under the well."
        )
    },
    %{
      id: "hex_blocks_sprint",
      mode_of: "hex_blocks",
      name: "Hex Blocks: Sprint",
      tagline: dgettext_noop("games", "Clear 40 rows against the clock"),
      description:
        dgettext_noop(
          "games",
          "Hex Blocks against the clock: clear 40 rows as fast as you can. The pieces never speed up. The faster your time, the higher your score."
        ),
      icon: "game_blocks",
      controls:
        dgettext_noop(
          "games",
          "Move and turn a piece with the arrow keys, and press the space bar to drop it. On a phone, tap the buttons under the well."
        )
    }
  ]

  rankings = [versus: @versus_game_ids, score: @score_game_ids, coop: @coop_game_ids]
  catalog_ids = Enum.map(@games, & &1.id)

  for id <- catalog_ids do
    case for({ranking, ids} <- rankings, id in ids, do: ranking) do
      [_one] ->
        :ok

      found ->
        raise CompileError,
          description: "game #{id} needs exactly one ranking, has #{inspect(found)}"
    end
  end

  for {_ranking, ids} <- rankings, id <- ids, id not in catalog_ids do
    raise CompileError, description: "ranked game #{id} is not in the catalogue"
  end

  for id <- @solo_only_game_ids, id not in @solo_game_ids or id not in @score_game_ids do
    raise CompileError,
      description: "one-player game #{id} must be played solo and ranked by score"
  end

  # ex_dna:disable-for-lines:32 two catalogues, one lookup API each over its own @games
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

  @spec solo_game_id?(String.t()) :: boolean()
  def solo_game_id?(id), do: id in @solo_game_ids

  @doc "Whether `id` is a game for one player alone: no opponent, partner or audience."
  @spec solo_only?(String.t()) :: boolean()
  def solo_only?(id), do: id in @solo_only_game_ids

  @spec game_ids() :: [String.t()]
  def game_ids, do: Enum.map(@games, & &1.id)

  @doc "The box-art name of a game (`game_pong`), or nil for an id not in the catalogue."
  @spec icon(String.t()) :: String.t() | nil
  def icon(id), do: Enum.find_value(@games, &(&1.id == id and &1.icon))

  @doc """
  The games that are games in their own right, not a mode of another: Hex
  Tennis, not "Hex Tennis: Quick Match". A mode names its game in `mode_of`.
  """
  @spec base_games() :: [game()]
  def base_games do
    @games
    |> Enum.reject(&Map.has_key?(&1, :mode_of))
    |> Enum.map(&translate_game/1)
  end

  @doc "The modes of `game_id`, in catalogue order; empty for a game without any."
  @spec modes_of(String.t()) :: [game()]
  def modes_of(game_id) do
    @games
    |> Enum.filter(&(Map.get(&1, :mode_of) == game_id))
    |> Enum.map(&translate_game/1)
  end

  @doc """
  The game a mode belongs to — `"hex_tennis"` for `"hex_tennis_quick"` — and
  the game itself for a game that is not a mode. Every mode of a game shares
  its channel and its page.
  """
  @spec base_id(String.t()) :: String.t()
  def base_id(game_id) do
    case Enum.find(@games, &(&1.id == game_id)) do
      %{mode_of: base_id} -> base_id
      _base_or_unknown -> game_id
    end
  end

  @doc "How a finished match of `game_id` is ranked."
  @spec ranking(String.t()) :: ranking()
  def ranking(game_id) when game_id in @coop_game_ids, do: :coop
  def ranking(game_id) when game_id in @score_game_ids, do: :score
  # Every versus game, and an id no longer in the catalogue (an old result).
  def ranking(_versus_or_retired), do: :versus

  @doc """
  The address-safe name of a game: `"hex-pong"` for `"hex_pong"`. Its public
  page and its channel are both named after it.
  """
  @spec slug(String.t()) :: String.t()
  def slug(game_id), do: String.replace(game_id, "_", "-")

  @doc """
  The word a command names `game_id`'s mode by — `"blitz"` for
  `hex_raid_blitz`, as in `/lfg blitz` — or nil for a game itself.
  """
  @spec mode_word(String.t()) :: String.t() | nil
  def mode_word(game_id) do
    case base_id(game_id) do
      ^game_id -> nil
      base_id -> String.replace_prefix(game_id, base_id <> "_", "")
    end
  end

  @doc "The channel where `game_id` and every mode of it is talked about: `#hex-pong`."
  @spec channel_name(String.t()) :: String.t()
  def channel_name(game_id), do: "#" <> slug(base_id(game_id))

  @doc "The channel every game's results are also announced in."
  @spec feed_channel() :: String.t()
  def feed_channel, do: "#retro-games"

  @doc "Every game channel, one per base game, in catalogue order."
  @spec channel_names() :: [String.t()]
  def channel_names,
    do: for(%{id: id} = game <- @games, not Map.has_key?(game, :mode_of), do: channel_name(id))

  @doc "The base game a channel belongs to; `:error` for any other channel."
  @spec game_for_channel(String.t()) :: {:ok, String.t()} | :error
  def game_for_channel("#" <> name) do
    case Enum.find(@games, &(not Map.has_key?(&1, :mode_of) and slug(&1.id) == name)) do
      %{id: id} -> {:ok, id}
      nil -> :error
    end
  end

  def game_for_channel(_name), do: :error

  defp translate_game(game), do: CatalogText.translate(game, "games")
end

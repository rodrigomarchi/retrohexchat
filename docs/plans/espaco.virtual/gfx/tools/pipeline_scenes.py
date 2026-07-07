"""Micro-scenes authored with the pipeline (semantic intent -> deterministic
resolve -> validate -> render). Larger, richer scenes rendered at a natural zoom.

    python3 pipeline_scenes.py            # build all
    python3 pipeline_scenes.py pond       # build one
"""
import sys
from pipeline import Scene, build


def pond():
    # The tileset only has convex water corners, so the lake is a clean rectangle —
    # no island, no inner corners, no artefacts. Lilies dot the open water; the banks
    # carry a few natural props.
    s = Scene(24, 16, "grass")
    s.water(5, 3, 18, 12)                    # rectangular lake, grass margin all round
    for (x, y) in [(7, 5), (12, 4), (16, 6), (9, 9), (14, 10)]:
        s.prop("water_lily", x, y)
    s.prop("water_lilies_cluster", 10, 6)
    s.prop("water_ripple", 8, 8)
    s.prop("water_ripple", 15, 5)
    s.prop("tree_stumps", 20, 2); s.prop("log_horizontal", 1, 7)
    s.prop("bush_round", 2, 13); s.prop("bush_round", 20, 13)
    return s


def churchyard():
    # The scene we iterated on endlessly — now bigger, authored as intent, validated.
    W, H = 21, 22
    s = Scene(W, H, "grass")
    cx = 9                                   # church axis (3-wide chapel at cols9-11? -> col9..11)
    # chapel at the back + entrance
    s.prop("roof_round_orange", cx, 0)      # cols9-11
    s.detail("door_arch_stone", cx + 1, 3)  # centred door (col10)
    # stone path, church-width (cols9-11), from the door to the front opening
    s.fill(cx, 5, cx + 2, H - 1, "gravel")
    # fence around the whole yard; front opening at the path (cols9-11)
    s.fence_rect(0, 4, W - 1, H - 1, openings=[(cx, H - 1), (cx + 1, H - 1), (cx + 2, H - 1)])
    for x in (cx, cx + 1, cx + 2):          # clear the back fence where the chapel sits
        s.fence[4][x] = False
    # graveyard: rows of tombs + statues on each side of the path, clear of the fence
    for (x, y) in [(2, 6), (5, 6), (2, 10), (5, 10)]:
        s.prop("stone_slab_round", x, y)
    s.prop("statue_relief", 2, 14); s.prop("statue_pawn", 5, 14)
    for (x, y) in [(13, 6), (16, 6), (13, 10), (16, 10)]:
        s.prop("stone_slab_round", x, y)
    s.prop("bush_dead_grey", 13, 14)        # a churchyard yew
    s.prop("bench_wood", 16, 15)
    for (x, y) in [(7, 8), (6, 18), (17, 18), (13, 12)]:
        s.prop("flowers_white", x, y)
    return s


def path_demo():
    # The path bug that cost us hours, now trivial + correct: a stone path the exact
    # width of the church. Seamless gravel (1x1) fill -> smooth, no stripes, aligned.
    s = Scene(13, 12, "grass")
    s.prop("roof_round_orange", 5, 0)      # 3-wide church (cols5-7)
    s.detail("door_arch_stone", 6, 3)
    s.fill(5, 5, 7, 11, "gravel")          # path cols5-7 == church width
    return s


def market():
    # A village market square: two awning stalls facing the gravel plaza, a tall
    # vendor table with produce crates displayed in front, a cargo corner and a
    # bench to rest. Greenery frames the square.
    s = Scene(22, 15, "grass")
    s.fill(2, 1, 19, 13, "gravel")           # the paved square; grass frames it
    s.prop("market_stall_awning", 3, 1)      # west stall (cols3-7, counter row6)
    s.prop("market_stall_awning", 13, 1)     # east stall (cols13-17)
    s.prop("counter_wood", 9, 4)             # open-air vendor table between them
    s.prop("stool_wood", 12, 4)              # the vendor's stool
    for i, crate in enumerate(["produce_crate_banana", "produce_crate_greens",
                               "produce_crate_tomato", "produce_crate_lemon"]):
        s.prop(crate, 7 + 2 * i, 7)          # produce displayed in front, spaced out
    s.prop("barrel_wood", 3, 10)             # cargo corner on the plaza
    s.prop("barrel_wood", 4, 10)
    s.prop("crate_x", 6, 10)
    s.prop("crate_wood", 3, 12)
    s.prop("sack_flour", 4, 12)
    s.prop("bench_wood", 15, 10)
    s.prop("bush_round", 0, 13)
    s.prop("bush_round", 20, 13)
    s.prop("flowers_white", 1, 5)
    s.prop("flowers_white", 20, 5)
    return s


def blacksmith_forge():
    # The smith's compound: the house at the back, a packed-dirt work yard in
    # front with the forge furnace + coal pile on one side and the workbench by
    # the door; quenching barrels, a chopping block and a log pile fill the yard.
    s = Scene(18, 13, "grass")
    s.prop("house_large", 2, 0)              # the smithy (cols2-6, door at bottom)
    s.fill(2, 5, 14, 10, "dirt")             # the work yard the door opens onto
    s.prop("anvil_forge", 12, 5)             # forge furnace (1x3), east side of yard
    s.prop("coal_rocks", 13, 6)              # coal heap feeding the furnace
    s.prop("barrel_wood", 10, 5)             # quenching barrels beside the furnace
    s.prop("barrel_wood", 11, 5)
    s.prop("counter_wood", 4, 6)             # workbench near the door
    s.prop("stool_wood", 7, 7)
    s.prop("hedge_block", 1, 1)              # vertical shrubs aligned to the walls
    s.prop("hedge_block", 1, 3)
    s.prop("hedge_block", 7, 1)
    s.prop("hedge_block", 7, 3)
    s.prop("flowerpot_sprout", 3, 5)         # potted sprouts flanking the door
    s.prop("flowerpot_sprout", 6, 5)
    s.prop("crate_x", 2, 8)
    s.prop("tree_stumps", 8, 9)              # chopping block
    s.prop("log_horizontal", 11, 9)          # log pile awaiting the axe
    s.prop("log_horizontal", 10, 10)
    s.prop("tree_foliage", 15, 1)            # green frame outside the yard
    s.prop("bush_round", 0, 11)
    s.prop("flowers_white", 16, 5)
    return s


def farmstead():
    # A fenced farm: barn at the top-left (front doors facing south), an L-shaped
    # gravel lane from the south gate up to the barn doors, two crop plots on the
    # east side split by a bush hedgerow, and the working yard (well, haystacks,
    # stores) in the bottom-left quadrant so the barn stands free.
    s = Scene(24, 18, "grass")
    s.fence_rect(0, 0, 23, 17, openings=[(10, 17), (11, 17)])
    s.prop("house_large", 2, 1)              # farmhouse, cols2-6, door facing south
    s.fill(3, 6, 11, 7, "gravel")            # lane, west leg: barn doors <- corner
    s.fill(10, 6, 11, 17, "gravel")          # lane, south leg: corner <- gate
    s.fill(13, 2, 20, 7, "crops")            # north field
    s.fill(13, 10, 20, 15, "crops")          # south field
    for x in (13, 15, 17, 19):
        s.prop("bush_round", x, 8)           # hedgerow splitting the two fields
    s.fill(2, 10, 8, 15, "dirt")             # working yard, bottom-left quadrant
    s.prop("well_lidded", 3, 11)
    s.prop("haystack", 6, 10)
    s.prop("haystack", 6, 13)
    s.prop("crate_wood", 2, 13)
    s.prop("sack_flour", 4, 14)
    s.prop("tree_foliage", 8, 2)             # shade tree NE of the house
    s.prop("bush_round", 7, 1)
    s.prop("flowers_white", 7, 4)
    s.prop("flowers_white", 11, 3)
    s.prop("tree_stumps", 2, 8)              # woodpile between lane and yard
    s.prop("log_horizontal", 4, 8)
    s.prop("log_horizontal", 5, 9)
    s.prop("flowers_white", 21, 4)
    s.prop("flowers_white", 13, 16)
    return s


def orchard():
    # A fenced orchard: two blocks of fruit trees in planted rows flanking a
    # gravel lane from the south gate, a harvest corner (produce + barrel) by
    # the lane, and one felled tree in the far corner.
    s = Scene(20, 15, "grass")
    s.fence_rect(0, 0, 19, 14, openings=[(9, 14), (10, 14)])
    s.fill(9, 2, 10, 14, "gravel")           # lane: gate -> heart of the orchard
    for ty in (2, 5, 8):                     # west block, planted rows
        for tx in (2, 5):
            s.prop("tree_foliage", tx, ty)
    for ty in (2, 5, 8):                     # east block
        for tx in (13, 16):
            s.prop("tree_foliage", tx, ty)
    s.prop("produce_crate_lemon", 7, 11)     # harvest corner by the lane
    s.prop("produce_crate_banana", 8, 12)
    s.prop("barrel_wood", 6, 12)
    s.prop("tree_stumps", 16, 11)            # the felled tree
    s.prop("flowers_white", 4, 11)
    s.prop("flowers_white", 13, 11)
    s.prop("flowers_white", 18, 4)
    s.prop("bush_round", 12, 12)
    return s


def graveyard():
    # A fenced graveyard (no chapel — that is the churchyard's): rows of round
    # tombstones flanking a lane, a stone arch monument at its head guarded by
    # two statues, a dead yew and quiet flowers.
    s = Scene(20, 15, "grass")
    s.fence_rect(0, 0, 19, 14, openings=[(9, 14), (10, 14)])
    s.prop("statue_relief", 5, 1)            # guardians watching over the yard
    s.prop("statue_relief", 13, 1)
    for (gx, gy) in [(2, 5), (2, 8), (5, 8), (5, 11),      # west tomb rows
                     (13, 5), (16, 8), (13, 8), (16, 11)]:  # east tomb rows
        s.prop("stone_slab_round", gx, gy)
    s.prop("grave_stone_a", 5, 5)            # humbler headstones mixed in
    s.prop("grave_stone_b", 3, 11)
    s.prop("grave_stone_b", 17, 5)
    s.prop("grave_stone_a", 13, 11)
    s.prop("bush_dead_grey", 16, 1)          # the graveyard yew
    s.prop("flowers_white", 4, 7)
    s.prop("flowers_white", 15, 10)
    s.prop("flowers_white", 7, 12)
    for (x, y) in [(12, 6), (7, 9), (15, 9), (4, 4), (9, 5),
                   (10, 10), (8, 13), (18, 8), (11, 2)]:  # scattered mementos mori
        s.prop("skull", x, y)
    s.prop("bone", 11, 12)
    s.prop("bone", 17, 4)
    return s


def campfire():
    # A camp clearing in the trees: a LIT campfire (flame over the coal heap) on
    # bare ground, a log and stumps to sit on, supplies at the clearing's edge,
    # rocks at the border.
    s = Scene(16, 12, "grass")
    s.fill(4, 4, 10, 8, "dirt")              # the trodden clearing
    s.prop("coal_bed", 7, 6)                 # the fire pit's coals, dead centre
    s.detail("flame_fire", 7, 5.5)           # flame half a tile up: bed stays visible
    s.prop("tree_stumps", 4, 5)              # seats west of the fire
    s.prop("log_horizontal", 6, 8)           # bench log south of the fire
    s.prop("crate_wood", 10, 4)              # camp supplies at the clearing edge
    s.prop("sack_flour", 9, 4)
    s.prop("rocks_row", 3, 9)
    s.prop("tree_foliage", 0, 0)             # the woods closing the clearing in
    s.prop("tree_foliage", 14, 0)
    s.prop("tree_foliage", 0, 9)
    s.prop("tree_foliage", 14, 9)
    s.prop("flowers_white", 2, 3)
    s.prop("flowers_white", 13, 7)
    return s


def well_plaza():
    # A small village square: the lidded well at the centre of a gravel plaza,
    # one bench, vertical hedges marking the four corners.
    s = Scene(13, 10, "grass")
    s.fill(2, 2, 10, 7, "gravel")
    s.prop("well_lidded", 5, 3)
    s.prop("bench_wood", 4, 6)
    for (x, y) in [(2, 2), (10, 2), (2, 6), (10, 6)]:
        s.prop("hedge_block", x, y)
    s.prop("flowers_white", 3, 4)
    s.prop("flowers_white", 9, 4)
    return s


def dock():
    # A river crossing: the stone bridge spans a 2-row channel (its side foam
    # sits exactly on the water rows), cargo waits on the south-west bank and
    # an islet breaks the water east of the bridge.
    s = Scene(18, 13, "grass")
    s.water(2, 6, 15, 9)                     # 4-row channel; bridge piers stand in it
    s.prop("bridge_castle", 7, 5)            # cols7-11; side foam on water rows7-8
    s.prop("crate_wood", 3, 10)              # the landing on the south bank
    s.prop("barrel_wood", 4, 10)
    s.prop("sack_flour", 5, 11)
    s.prop("rock_islet", 13, 7)
    s.prop("water_lily", 4, 7)
    s.prop("bush_round", 14, 11)
    s.prop("tree_foliage", 1, 2)
    return s


def ruins():
    # An abandoned watchtower: the open-topped shell stands on a bare court,
    # the rubble of its upper floors heaped at its foot, a dead tree beside it.
    s = Scene(13, 11, "grass")
    s.fill(3, 6, 9, 9, "dirt")               # the trampled court at its foot
    s.prop("tower_stone_round", 4, 1)        # cols4-6, footing rests on the court
    s.prop("rock_pile", 7, 6)                # fallen masonry against the base
    s.prop("rock_boulder", 8, 7)
    s.prop("rocks_row", 4, 8)                # rubble strewn across the court
    s.prop("rock_pebbles_scatter", 3, 7)
    s.prop("rock_pebbles_scatter", 8, 9)
    s.prop("skull", 7, 7)                    # the last sentry
    s.prop("bush_dead_grey", 8, 2)           # a dead tree beside the shell
    return s


def fortress_gate():
    # The fortress approach: the gatehouse rises behind its moat, the stone
    # bridge carries the road across, pawn obelisks watch the south bank.
    # (The gate sprite was drawn to stand at water — the moat is its context.)
    s = Scene(16, 15, "grass")
    s.prop("castle_gate", 5, 0)              # cols5-9 rows0-5, arch mouth at 7-8
    s.fill(6, 4, 8, 5, "gravel")             # paving filling the arch passage
    s.water(2, 6, 13, 9)                     # the moat (4 rows: 2 open water)
    s.detail("bridge_castle", 5, 5)          # bridge butted against the gate
    s.fill(7, 10, 8, 14, "gravel")           # road butted to the south landing
    s.prop("statue_pawn", 3, 10)
    s.prop("statue_pawn", 12, 10)
    s.prop("bush_round", 1, 1)
    s.prop("bush_round", 13, 1)
    return s


def village_gate():
    # The village boundary: a fence line broken by the stone arch gate, the
    # road running through it, trees and bushes softening the wall.
    s = Scene(14, 9, "grass")
    s.fence_rect(0, 3, 13, 3, openings=[(5, 3), (6, 3), (7, 3), (8, 3)])
    s.fill(6, 0, 7, 8, "gravel")             # the road through the gate
    s.detail("gate_arch_wood", 5, 1)         # arch capping the fence gap
    s.prop("bush_round", 3, 2)
    s.prop("bush_round", 9, 2)
    s.prop("tree_foliage", 1, 5)
    s.prop("tree_foliage", 11, 5)
    s.prop("flowers_white", 4, 6)
    s.prop("flowers_white", 9, 6)
    return s


def fountain_garden():
    # A formal garden: the fountain at the centre, clipped hedges at the four
    # corners, flowers between them and one bench to sit and listen.
    s = Scene(13, 11, "grass")
    s.prop("fountain_stone", 5, 4)           # cols5-7 rows4-6
    for (x, y) in [(2, 2), (10, 2), (2, 7), (10, 7)]:
        s.prop("hedge_block", x, y)
    for (x, y) in [(4, 3), (8, 3), (4, 7), (8, 7)]:
        s.prop("flowers_white", x, y)
    s.prop("bench_wood", 5, 8)
    return s


def forest_shrine():
    # A shrine deep in the woods: skull idol between two totems on a bare
    # earth pad, offering pots before them, the forest closing in.
    s = Scene(13, 10, "grass")
    s.fill(5, 3, 9, 6, "dirt")
    s.prop("statue_totem_a", 5, 3)
    s.prop("idol_skull", 7, 3)
    s.prop("statue_totem_b", 9, 3)
    s.prop("pot_stone_a", 6, 6)
    s.prop("pot_stone_b", 8, 6)
    for (x, y) in [(0, 0), (11, 0), (0, 7), (11, 7)]:
        s.prop("tree_foliage", x, y)
    s.prop("flowers_white", 4, 7)
    s.prop("flowers_white", 10, 7)
    return s


def stepping_stones():
    # A creek crossed on stepping stones: the path reaches both banks and the
    # stones carry it over the water; an islet sits downstream.
    s = Scene(15, 9, "grass")
    s.water(2, 3, 12, 6)                     # 4 rows: the middle two are open water
    s.fill(6, 0, 7, 2, "gravel")
    s.fill(6, 7, 7, 8, "gravel")
    s.prop("stepping_stones", 5, 4)          # cols5-7, on the open-water rows
    s.prop("stepping_stone", 6, 5)
    s.prop("stepping_stone", 7, 5)
    s.prop("rock_islet", 10, 4)
    s.prop("water_lily", 3, 5)
    s.prop("tree_foliage", 1, 0)
    s.prop("bush_round", 11, 7)
    return s


def witch_camp():
    # A witch's camp on scorched ground: the cauldron, a small fire, offering
    # pots, and bones where visitors stood too long.
    s = Scene(14, 11, "grass")
    s.fill(4, 3, 9, 8, "dirt")
    s.prop("cauldron_grey", 6, 4)            # pot art sits at x6.5-7.5, y4.3-5.2
    s.detail("coal_bed", 6.5, 6.1)           # fire bed aligned right under the pot
    s.detail("flame_fire", 6.5, 5.2)         # flames licking the cauldron's base
    s.prop("pot_stone_a", 8, 5)
    s.prop("pot_stone_b", 9, 5)
    for (x, y) in [(4, 4), (9, 7), (11, 9)]:
        s.prop("skull", x, y)
    s.prop("bone", 7, 8)
    s.prop("bush_dead_grey", 11, 1)
    s.prop("tree_foliage", 0, 0)
    s.prop("tree_foliage", 0, 8)
    return s


def boulder_field():
    # A rocky outcrop in the meadow: one great mossy boulder and its satellites
    # trailing off into pebbles and tufts.
    s = Scene(13, 9, "grass")
    s.prop("boulder_pile", 5, 3)             # cols5-6 rows3-4
    s.prop("rock_boulder", 8, 2)
    s.prop("rock_pile", 3, 5)
    s.prop("rocks_row", 7, 6)
    s.prop("rock_small", 4, 2)
    s.prop("rock_pebbles_scatter", 6, 6)
    s.prop("rock_pebbles_scatter", 9, 4)
    s.prop("pebble_stone", 2, 3)
    return s


def river_rapids():
    # A broad river broken by rock: the great smooth boulder mid-stream, a run
    # of foaming rocks below it, a cluster upstream — quiet banks either side.
    s = Scene(18, 12, "grass")
    s.water(1, 2, 16, 9)                     # 8-row river: rows3-8 open water
    s.prop("river_boulder", 5, 4)            # the great stone, mid-stream
    s.prop("river_rocks", 9, 6)              # foaming run below it
    s.prop("river_rock_cluster", 12, 3)      # upstream cluster
    s.prop("water_ripple", 8, 3)
    s.prop("water_ripple", 14, 7)
    s.prop("water_lily", 3, 7)
    s.prop("tree_foliage", 13, 0)
    s.prop("bush_round", 2, 10)
    return s


def hillside_cave():
    # The hillside: a south-facing escarpment crosses the scene, the cave mouth
    # opens at ground level, a trail leads away from it; the woods sit on the
    # plateau above, rocks at the cliff's foot.
    s = Scene(16, 10, "grass")
    s.cliff_south(0, 15, 3)                  # lip row3, footed base row4
    s.detail("cave_mouth", 7, 2)             # mouth column + its plateau crack
    s.fill(7, 5, 7, 9, "gravel")             # trail from the entrance
    s.prop("tree_foliage", 1, 0)             # the woods up on the plateau
    s.prop("tree_foliage", 11, 0)
    s.prop("bush_round", 5, 1)
    s.prop("rock_pile", 3, 6)                # scree at the cliff's foot
    s.prop("rock_boulder", 11, 5)
    s.prop("rock_pebbles_scatter", 5, 5)
    s.prop("bush_round", 12, 8)
    s.prop("flowers_white", 3, 8)
    return s


def stump_grove():
    # A felled corner of the woods — except one of the stumps is asleep.
    s = Scene(12, 9, "grass")
    s.prop("tree_foliage", 1, 1)
    s.prop("tree_foliage", 8, 1)
    s.prop("tree_foliage", 2, 6)
    s.prop("stump_plain", 3, 3)
    s.prop("stump_creature_sleep", 5, 4)     # the one that snores
    s.prop("stump_plain", 8, 5)
    s.prop("bush_clover", 7, 3)
    s.prop("bush_clover", 4, 6)
    s.prop("flowers_white", 6, 2)
    s.prop("flowers_white", 9, 4)
    return s


SCENES = {"pond": pond, "path_demo": path_demo, "churchyard": churchyard,
          "market": market, "blacksmith_forge": blacksmith_forge,
          "farmstead": farmstead, "orchard": orchard, "graveyard": graveyard,
          "campfire": campfire, "well_plaza": well_plaza, "dock": dock,
          "ruins": ruins, "fortress_gate": fortress_gate,
          "village_gate": village_gate, "fountain_garden": fountain_garden,
          "forest_shrine": forest_shrine, "stepping_stones": stepping_stones,
          "witch_camp": witch_camp, "boulder_field": boulder_field,
          "stump_grove": stump_grove, "river_rapids": river_rapids,
          "hillside_cave": hillside_cave}

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(SCENES)):
        build(n, SCENES[n]())

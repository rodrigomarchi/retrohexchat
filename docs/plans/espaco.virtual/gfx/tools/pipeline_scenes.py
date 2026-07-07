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
    for gy in (5, 8, 11):                    # west tomb rows
        for gx in (2, 5):
            s.prop("stone_slab_round", gx, gy)
    for gy in (5, 8, 11):                    # east tomb rows
        for gx in (13, 16):
            s.prop("stone_slab_round", gx, gy)
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


SCENES = {"pond": pond, "path_demo": path_demo, "churchyard": churchyard,
          "market": market, "blacksmith_forge": blacksmith_forge,
          "farmstead": farmstead, "orchard": orchard, "graveyard": graveyard,
          "campfire": campfire}

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(SCENES)):
        build(n, SCENES[n]())

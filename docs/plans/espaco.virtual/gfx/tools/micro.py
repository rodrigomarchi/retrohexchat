"""Micro-scenes: small, self-contained tile compositions rendered large so each
semantic unit (a cottage, the smithy, the well, a creek crossing...) can be
refined in isolation before being assembled into the full village. Run:

    python3 micro.py                 # render every scene
    python3 micro.py cottage smithy  # render just these

Outputs one PNG per scene under gfx/previews/scenes/. Rect fixes for the known
mis-sized catalog entries are applied up front (see overworld-catalog-rect-bugs).
"""
import os, sys
from PIL import Image
from showcase import Map, slice_tile, CAT   # CAT already has RECT_FIX applied

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "previews", "scenes")
os.makedirs(OUT, exist_ok=True)

SCENES = {}


def scatter(m, spots, name):
    for (x, y) in spots:
        m.p(x, y, name)


def fence_row(m, x0, x1, y, gap=None):
    """A picket fence along row y (fence_wood is a 1x2 post), leaving a 2-tile
    opening at `gap` for a path/entrance instead of a clipping gate sprite."""
    for x in range(x0, x1 + 1):
        if gap is not None and x in (gap, gap + 1):
            continue
        m.p(x, y, "fence_wood")


def scene(fn):
    SCENES[fn.__name__] = fn
    return fn


def render(name, scale=6):
    m = SCENES[name]()
    img = m.render(scale)
    img.convert("RGB").save(os.path.join(OUT, name + ".png"))
    print(f"{name}: {m.w}x{m.h} tiles, {len(m.used)} sprites -> {sorted(m.used)}")


# ---------------------------------------------------------------------------
# Human-activity scenes
# ---------------------------------------------------------------------------
@scene
def cottage():
    m = Map(9, 10)
    m.p(2, 1, "house_large")                 # 5x5 complete cottage sprite
    m.p(4, 1, "chimney_stone")               # sits on the roof, not floating above
    for y in (6, 7):                          # kitchen garden in front
        for x in range(2, 7):
            m.g(x, y, "crops_field")
    m.p(2, 6, "planter_box"); m.p(5, 7, "flowerpot_plant")
    fence_row(m, 1, 7, 8, gap=4)             # picket fence with a gated opening
    m.road_h(0, 8, 9, w=1)                    # the lane the cottage fronts onto
    return m


@scene
def well_plaza():
    m = Map(12, 10)
    m.g(6, 4, "cobblestone_path")             # stone dais
    m.p(6, 4, "fountain_stone")
    m.p(2, 4, "well_stone")                    # stone well, off to one side
    m.p(9, 4, "bench_wood"); m.p(2, 7, "bench_wood")
    m.p(6, 2, "flag_blue")
    m.p(5, 7, "lamp_post"); m.p(10, 7, "lamp_post")
    m.g(4, 8, "dirt_patch")
    return m


@scene
def flower_corner():
    m = Map(7, 6)
    m.p(2, 2, "planter_box")
    m.p(1, 3, "flowerpot_plant"); m.p(4, 3, "flowerpot_sprout")
    m.p(5, 1, "bush_round"); m.p(1, 1, "flowers_white"); m.p(4, 4, "flowers_white")
    return m


@scene
def market_stall():
    m = Map(11, 10)
    m.p(2, 1, "market_stall_awning")          # 6x5
    m.p(3, 6, "market_table")
    m.row(2, 8, ["produce_crate_banana", "produce_crate_greens",
                 "produce_crate_tomato", "produce_crate_lemon"], gap=0)
    m.p(8, 5, "counter_wood")
    m.p(1, 6, "barrel_wood"); m.p(7, 8, "crate_wood"); m.p(8, 7, "sack_flour")
    return m


@scene
def smithy():
    # Open-air forge: anvil_forge is already a complete furnace+anvil. Back it with
    # a log-wall lean-to and surround with a workbench, quench barrel and stock.
    # Open-air forge — anvil_forge is a complete furnace+anvil; keep the stock tight
    # around it (log_wall floated as a lean-to, so it lives on the farm shed instead).
    m = Map(8, 7)
    m.p(3, 1, "anvil_forge")                   # forge (furnace + anvil)
    m.p(1, 2, "barrel_wood")                   # quench barrel, beside it
    m.p(5, 1, "counter_wood")                  # workbench, beside it
    m.p(2, 5, "planks_pile"); m.p(5, 4, "crate_wood")
    return m


@scene
def merchant_camp():
    m = Map(9, 8)
    m.p(1, 1, "tent_wood")                     # 2x3
    m.p(4, 2, "stump_table")
    m.p(4, 5, "stool_wood"); m.p(6, 3, "stool_wood")
    m.p(6, 5, "crate_open"); m.p(3, 5, "barrel_wood")
    m.p(7, 1, "banner_blue")
    return m


@scene
def shrine():
    m = Map(8, 8)
    m.p(2, 1, "arch_stone")                    # 4x2 freestanding arch
    m.p(2, 4, "statue_relief"); m.p(5, 4, "statue_pawn")
    m.p(0, 6, "stone_slab_round")
    m.p(1, 3, "flowerpot_sprout")
    return m


# ---------------------------------------------------------------------------
# Structures & nature
# ---------------------------------------------------------------------------
@scene
def churchyard():
    # A fenced churchyard: the bell-tower chapel at the back, a stone path (the width
    # of the church, cols5-7) down the middle to a FRONT OPENING in the picket fence,
    # with graves and a bench inside the enclosure.
    m = Map(13, 13)
    m.p(5, 0, "roof_round_orange")             # chapel at the back, centred on col6
    m.p(6, 3, "door_arch_stone")               # arched entrance on the axis (col6)
    # stone path the FULL WIDTH OF THE CHURCH (cols5-7). gravel_light is 2x2, so all
    # three ground columns must be set or the neighbouring grass overdraws the edge.
    for y in range(5, 13):
        for x in (5, 6, 7):
            m.g(x, y, "gravel_light")
    # fence right at the image edges: horizontal panels (fence_h) on the back & front
    # rows flanking the chapel/opening, vertical posts (fence_wood) down the sides
    for x in (0, 2, 8, 10):
        m.p(x, 4, "fence_h")                   # back fence (chapel gap at cols4-7)
        m.p(x, 12, "fence_h")                  # front fence (entrance gap at cols4-7)
    for y in (5, 7, 9):
        m.p(0, y, "fence_wood"); m.p(12, y, "fence_wood")   # side fences at the edges
    # graves (left) + bench and yew (right), inside the enclosure
    m.p(2, 5, "statue_relief"); m.p(3, 8, "stone_slab_round")
    m.p(8, 5, "bench_wood"); m.p(8, 8, "bush_dead_grey")
    m.p(2, 9, "flowers_white")
    return m


@scene
def creek_bridge():
    m = Map(14, 8)
    m.pond(0, 3, 13, 5, lilies=[(2, 4), (10, 4)])
    m.g(4, 4, "water_deep"); m.g(8, 3, "water_ripple"); m.g(11, 4, "water_fill")
    m.p(3, 4, "water_lilies_cluster")
    m.road_v(6, 0, 2, w=2); m.road_v(6, 6, 7, w=2)                  # road approaches
    m.p(5, 0, "bridge_castle")                 # 5x6 crossing
    m.p(0, 1, "tree_trunk_vertical"); m.p(11, 1, "tree_stumps")   # trunk clear of the lilies
    m.p(1, 6, "bush_round"); m.p(9, 6, "log_horizontal")
    return m


@scene
def farmstead():
    # No fountain_basin (reads as a cannon) and no floating trapdoors. Barn, a
    # fronting crop field, hay/storage, a paddock and a tool shed.
    m = Map(15, 13)
    m.p(1, 1, "barn_large")                    # 5x6 barn (cols1-5, rows1-6)
    m.p(2, 6, "cellar_door_dark")              # arched undercroft at the barn's base
    m.p(7, 1, "haystack"); m.p(9, 3, "haystack")
    for y in range(8, 11):                     # crop field in front
        for x in range(1, 12):
            m.g(x, y, "crops_field")
    fence_row(m, 1, 11, 11, gap=6)
    m.p(7, 5, "sack_flour"); m.p(9, 6, "crate_wood"); m.p(11, 6, "planks_pile")
    m.p(11, 1, "log_wall"); m.p(12, 3, "door_wood")     # tool shed (roof + door)
    return m


@scene
def quarry():
    # No boulder_large here — it's river-rock with white foam and reads wrong dry.
    m = Map(13, 9)
    m.cliff_south(0, 12, 1)
    m.p(2, 1, "cave_entrance")                  # mine adit in the cliff
    m.p(9, 2, "cave_hole")
    for (x, y) in [(2, 6), (3, 6), (2, 7), (3, 7)]:
        m.g(x, y, "cliff_rock_fill")            # broken-rock ground
    m.p(1, 5, "coal_rocks"); m.p(9, 5, "rocks_row")
    m.p(5, 6, "rock_small"); m.p(11, 7, "rock_small")
    m.p(6, 4, "crate_wood"); m.p(4, 8, "planks_pile"); m.p(8, 7, "sack_flour")
    return m


@scene
def ruined_gate():
    m = Map(14, 8)
    m.cliff_south(0, 13, 1)
    m.p(1, 0, "tower_stone_round")             # 3x6
    m.p(6, 0, "castle_gate")                   # 5x6
    m.p(4, 1, "stone_wall_arch"); m.p(11, 1, "stone_wall_arch")
    m.p(2, 0, "flag_blue"); m.p(8, 1, "banner_blue")
    return m


@scene
def orchard_field():
    m = Map(14, 12)
    for (x, y) in [(x, y) for y in (1, 4) for x in (1, 5, 9)]:
        m.p(x, y, "tree_foliage")              # rows of fruit trees (clean 2x2 canopy)
    for y in range(8, 10):                     # a small crop field below
        for x in range(1, 11):
            m.g(x, y, "crops_field")
    fence_row(m, 1, 10, 10, gap=5)
    m.p(5, 8, "fence_gate_frame")              # tall entrance gate standing in the opening
    scatter(m, [(12, y) for y in range(1, 9, 2)], "hedge_block")   # hedgerow (1x2, no overlap)
    m.p(12, 9, "haystack")
    return m


if __name__ == "__main__":
    for n in (sys.argv[1:] or list(SCENES)):
        render(n)

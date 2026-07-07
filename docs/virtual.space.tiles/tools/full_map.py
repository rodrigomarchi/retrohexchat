"""The full overworld map: every approved micro-scene placed on one 92x68 grid
with geographic logic — village centre, farmland east, church west, wilds south
of the river, escarpment north. One road spine crosses it south->north (bridge,
village gate, market, well crossroads, cave mouth) with an east fork to the
fortress gate; the river crosses west->east with three crossings (stepping
stones / bridge / impassable rapids) and the lake as a backwater.

    python3 full_map.py          # render full_map.png + _full_map_view.png
"""
import os
from PIL import Image
from pipeline import Scene, OUT

W, H = 92, 68


def tree_frame(s):
    """The ALttP screen frame: a tree ring, broken where the river leaves.
    The north edge is deep woods — a staggered second and third rank."""
    for x in range(0, W - 1, 2):
        s.prop("tree_foliage", x, 0)
        s.prop("tree_foliage", x, H - 2)
    for y in range(2, H - 3, 2):
        if y in (40, 42):                        # the river flows off-map
            continue
        s.prop("tree_foliage", 0, y)
        s.prop("tree_foliage", W - 2, y)
    for x in range(3, W - 4, 4):                 # second rank, staggered
        s.prop("tree_foliage", x, 2)
    for x in (9, 21, 33, 57, 69, 81):            # third rank feathering the edge
        s.prop("tree_foliage", x, 4)
    for (x, y) in [(64, 8), (74, 6), (84, 9), (58, 7), (79, 11)]:
        s.prop("tree_foliage", x, y)             # loose woods filling the NE


def roads_and_river(s):
    # main road: well plaza (village's end) -> market -> village gate -> bridge
    s.fill(46, 14, 47, 16, "gravel")
    s.fill(46, 30, 47, 39, "gravel")             # market -> gate -> bridge bank
    s.fill(46, 44, 47, 44, "gravel")             # under the bridge's south margin
    s.fill(46, 45, 47, 51, "gravel")             # bridge -> shrine (road's end)
    # the river: 4 rows, full width, open water rows41-42
    s.water(0, 40, 91, 43)
    s.prop("stepping_stones", 28, 41)            # the wild crossing (west trail)
    s.prop("stepping_stone", 28, 42)
    s.prop("stepping_stone", 29, 42)
    s.fill(28, 32, 29, 39, "gravel")             # trail: church lane -> the stones
    s.fill(28, 44, 29, 49, "gravel")             # ...and on to the old graveyard
    s.prop("river_boulder", 60, 41)              # the rapids: no crossing east
    s.prop("river_rocks", 68, 41)
    s.prop("river_rock_cluster", 76, 41)
    s.prop("water_ripple", 12, 41)
    s.prop("water_ripple", 38, 42)
    s.prop("water_ripple", 55, 42)
    s.prop("water_ripple", 84, 41)
    s.prop("water_lily", 6, 42)
    s.prop("water_lily", 52, 41)
    s.prop("water_lily", 88, 42)
    # cargo landed by the bridge (the old dock)
    s.prop("barrel_wood", 41, 45)
    s.prop("crate_wood", 42, 45)
    s.prop("sack_flour", 41, 47)


def well_crossroads(s):
    """The well plaza sits where the fortress road forks off the main road."""
    s.fill(42, 8, 52, 13, "gravel")
    s.prop("well_lidded", 49, 9)
    s.prop("bench_wood", 43, 9)
    s.prop("hedge_block", 42, 8)
    s.prop("hedge_block", 51, 8)
    s.prop("hedge_block", 42, 12)
    s.prop("hedge_block", 51, 12)
    s.prop("flowers_white", 44, 12)
    s.prop("flowers_white", 50, 12)


def market_square(s):
    s.fill(34, 17, 51, 29, "gravel")             # the paved square (road runs through)
    s.prop("market_stall_awning", 35, 17)
    s.prop("market_stall_awning", 45, 17)
    s.prop("counter_wood", 41, 20)
    s.prop("stool_wood", 44, 20)
    for i, crate in enumerate(["produce_crate_banana", "produce_crate_greens",
                               "produce_crate_tomato", "produce_crate_lemon"]):
        s.prop(crate, 39 + 2 * i, 23)
    s.prop("barrel_wood", 35, 26)
    s.prop("barrel_wood", 36, 26)
    s.prop("crate_x", 38, 26)
    s.prop("crate_wood", 35, 28)
    s.prop("sack_flour", 36, 28)
    s.prop("bench_wood", 49, 26)


def forge_quarter(s):
    s.prop("house_large", 26, 16)                # the smithy west of the square
    s.prop("hedge_block", 25, 16)
    s.prop("hedge_block", 25, 18)
    s.prop("hedge_block", 31, 16)
    s.prop("hedge_block", 31, 18)
    s.fill(26, 21, 33, 28, "dirt")
    s.prop("flowerpot_sprout", 27, 21)
    s.prop("flowerpot_sprout", 30, 21)
    s.prop("anvil_forge", 33, 21)
    s.prop("coal_rocks", 31, 24)
    s.prop("barrel_wood", 31, 21)
    s.prop("barrel_wood", 32, 21)
    s.prop("counter_wood", 26, 23)
    s.prop("stool_wood", 29, 24)
    s.prop("crate_x", 26, 27)
    s.prop("tree_stumps", 29, 26)
    s.prop("log_horizontal", 31, 27)


def fountain_garden_(s):
    s.prop("fountain_stone", 58, 23)             # formal garden east of the square
    s.prop("hedge_block", 55, 21)
    s.prop("hedge_block", 63, 21)
    s.prop("hedge_block", 55, 28)
    s.prop("hedge_block", 63, 28)
    s.prop("flowers_white", 57, 22)
    s.prop("flowers_white", 61, 22)
    s.prop("flowers_white", 57, 27)
    s.prop("flowers_white", 61, 27)
    s.prop("bench_wood", 58, 28)


def village_gate_(s):
    """The south boundary of the village, on the main road above the bridge."""
    s.fence_rect(38, 36, 56, 36,
                 openings=[(45, 36), (46, 36), (47, 36), (48, 36)])
    s.fill(45, 34, 48, 36, "gravel")             # paved passage, full arch width
    s.detail("gate_arch_wood", 45, 34)
    s.prop("bush_round", 42, 35)
    s.prop("bush_round", 50, 35)
    s.prop("tree_foliage", 39, 32)
    s.prop("tree_foliage", 53, 30)
    s.prop("flowers_white", 44, 38)
    s.prop("flowers_white", 50, 38)


def churchyard_(s):
    """The chapel + its graves, west quarter (ported from the approved scene)."""
    s.fence_rect(4, 12, 24, 29, openings=[(13, 29), (14, 29), (15, 29)])
    s.prop("roof_round_orange", 13, 8)           # bell tower, cols13-15
    s.detail("door_arch_stone", 14, 11)
    for x in (13, 14, 15):                       # chapel sits over the back fence
        s.fence[12][x] = False
    s.fill(13, 13, 15, 29, "gravel")             # nave path to the front gate
    s.fill(13, 30, 15, 30, "gravel")             # ...stepping out to the lane
    s.fill(16, 30, 45, 31, "gravel")             # lane east to the main road
    for (x, y) in [(6, 14), (9, 14), (6, 18), (9, 18)]:
        s.prop("stone_slab_round", x, y)
    s.prop("statue_relief", 6, 22)
    s.prop("statue_pawn", 9, 22)
    for (x, y) in [(17, 14), (20, 14), (17, 18), (20, 18)]:
        s.prop("stone_slab_round", x, y)
    s.prop("bush_dead_grey", 17, 22)
    s.prop("bench_wood", 20, 26)
    for (x, y) in [(11, 16), (10, 26), (21, 25), (17, 20)]:
        s.prop("flowers_white", x, y)


def orchard_(s):
    """Below the churchyard, sharing its path: chapel -> orchard -> river bank."""
    s.fence_rect(4, 31, 25, 39, openings=[(13, 31), (14, 31), (15, 31)])
    s.fill(13, 31, 15, 38, "gravel")             # paved straight through the gate
    for ty in (32, 35):
        for tx in (6, 9):
            s.prop("tree_foliage", tx, ty)
    for ty in (32, 35):
        for tx in (18, 21):
            s.prop("tree_foliage", tx, ty)
    s.prop("produce_crate_lemon", 17, 37)
    s.prop("barrel_wood", 11, 37)
    s.prop("flowers_white", 5, 37)
    s.prop("flowers_white", 23, 37)


def farmstead_(s):
    """The fenced farm, east: lane in from the south, house, fields, yard."""
    s.fence_rect(64, 14, 87, 31, openings=[(72, 31), (73, 31)])
    s.prop("house_large", 66, 15)
    s.fill(68, 20, 73, 21, "gravel")             # from the door...
    s.fill(72, 22, 73, 33, "gravel")             # ...down through the gate
    s.fill(48, 32, 71, 33, "gravel")             # village street: farm -> main road
    s.fill(76, 16, 85, 21, "crops")
    s.fill(76, 24, 85, 29, "crops")
    for x in (76, 78, 80, 82, 84):
        s.prop("bush_round", x, 22)              # hedgerow between the fields
    s.fill(65, 20, 70, 29, "dirt")               # the working yard
    s.prop("well_lidded", 65, 22)
    s.prop("haystack", 66, 25)
    s.prop("haystack", 66, 28)
    s.prop("crate_wood", 69, 25)
    s.prop("sack_flour", 69, 28)
    s.prop("tree_stumps", 65, 20)


def boulder_field_(s):
    """The rocky waste under the cliff, west of the crossroads."""
    s.prop("boulder_pile", 32, 8)
    s.prop("rock_boulder", 36, 7)
    s.prop("rock_pile", 30, 10)
    s.prop("rocks_row", 34, 11)
    s.prop("rock_small", 31, 6)
    s.prop("rock_pebbles_scatter", 37, 10)
    s.prop("rock_pebbles_scatter", 29, 8)
    s.prop("pebble_stone", 38, 12)


def south_wilds(s):
    # stump grove strip on the west bank
    s.prop("tree_foliage", 3, 44)
    s.prop("tree_foliage", 12, 44)
    s.prop("stump_plain", 5, 46)
    s.prop("stump_creature_sleep", 8, 45)
    s.prop("stump_plain", 10, 47)
    s.prop("bush_clover", 7, 48)
    s.prop("bush_clover", 11, 45)
    s.prop("flowers_white", 4, 48)
    # witch camp, deep south-west
    s.fill(5, 55, 11, 61, "dirt")
    s.prop("cauldron_grey", 7, 56)
    s.detail("coal_bed", 7.5, 58.1)
    s.detail("flame_fire", 7.5, 57.2)
    s.prop("pot_stone_a", 10, 57)
    s.prop("pot_stone_b", 10, 59)
    for (x, y) in [(5, 57), (9, 60), (13, 62), (6, 62)]:
        s.prop("skull", x, y)
    s.prop("bone", 8, 61)
    s.prop("bush_dead_grey", 12, 52)
    s.prop("tree_foliage", 2, 52)
    s.prop("tree_foliage", 14, 64)
    # the old graveyard, off the stepping-stones trail
    s.fence_rect(18, 50, 37, 64, openings=[(28, 50), (29, 50)])
    s.fill(28, 50, 29, 51, "gravel")             # trail carries through the gate
    s.prop("statue_relief", 23, 51)
    s.prop("statue_relief", 31, 51)
    s.prop("bush_dead_grey", 34, 51)
    for (x, y) in [(20, 55), (20, 61), (31, 55), (34, 61)]:
        s.prop("stone_slab_round", x, y)
    s.prop("grave_stone_a", 23, 55)
    s.prop("grave_stone_b", 24, 61)
    s.prop("grave_stone_b", 35, 55)
    s.prop("grave_stone_a", 31, 61)
    for (x, y) in [(26, 52), (30, 56), (22, 57), (33, 59), (27, 61)]:
        s.prop("skull", x, y)
    s.prop("bone", 25, 59)
    s.prop("bone", 35, 57)
    s.prop("flowers_white", 21, 58)
    s.prop("flowers_white", 33, 62)
    # the forest shrine, at the road's end
    s.fill(42, 52, 50, 56, "dirt")
    s.prop("statue_totem_a", 43, 52)
    s.prop("idol_skull", 46, 52)
    s.prop("statue_totem_b", 49, 52)
    s.prop("pot_stone_a", 44, 55)
    s.prop("pot_stone_b", 48, 55)
    s.prop("tree_foliage", 40, 50)
    s.prop("tree_foliage", 40, 58)
    # travellers' campfire east of the road
    s.fill(55, 48, 61, 53, "dirt")
    s.prop("coal_bed", 58, 50)
    s.detail("flame_fire", 58, 49.5)
    s.prop("tree_stumps", 55, 49)
    s.prop("log_horizontal", 57, 53)
    s.prop("sack_flour", 60, 48)
    s.prop("rocks_row", 54, 54)
    s.prop("tree_foliage", 53, 46)
    s.prop("tree_foliage", 53, 56)
    # the ruined watchtower guarding the old east road
    s.prop("tower_stone_round", 69, 45)
    s.fill(67, 52, 75, 55, "dirt")
    s.prop("rock_pile", 72, 52)
    s.prop("rock_boulder", 74, 53)
    s.prop("rocks_row", 68, 54)
    s.prop("rock_pebbles_scatter", 67, 53)
    s.prop("skull", 73, 54)
    s.prop("bush_dead_grey", 76, 48)
    # the lake, south-east backwater
    s.water(72, 58, 87, 64)
    s.prop("water_lily", 75, 60)
    s.prop("water_lilies_cluster", 78, 59)
    s.prop("water_lily", 82, 61)
    s.prop("water_ripple", 74, 62)
    s.prop("water_ripple", 84, 59)
    s.prop("rock_islet", 80, 61)
    s.prop("tree_stumps", 70, 57)
    s.prop("bush_round", 69, 63)
    s.prop("bush_round", 87, 56)
    # loose woods filling the south band
    for (x, y) in [(16, 46), (33, 45), (38, 46), (50, 59), (63, 59), (64, 44)]:
        s.prop("tree_foliage", x, y)


def life_scatter(s):
    """Hand-placed accents so the empty greens read alive, not vacant."""
    # NW meadow between the churchyard and the ridge
    for (x, y) in [(7, 8), (18, 9), (12, 7)]:
        s.prop("flowers_white", x, y)
    s.prop("bush_round", 9, 10)
    s.prop("rock_small", 21, 8)
    s.fill(14, 10, 15, 11, "grass_dark")
    # village greens
    s.prop("flowers_white", 37, 14)
    s.prop("bush_round", 42, 15)
    s.prop("flowers_white", 53, 17)
    s.prop("bush_clover", 55, 15)
    s.fill(39, 15, 40, 15, "grass_dark")
    # east band between garden and farm
    s.prop("bush_round", 60, 14)
    s.prop("flowers_white", 62, 18)
    s.prop("bush_clover", 61, 31)
    s.fill(59, 30, 60, 31, "grass_dark")         # clear of the farm street
    # band above the river
    for (x, y) in [(21, 34), (33, 34), (58, 35), (66, 34)]:
        s.prop("flowers_white", x, y)
    s.prop("bush_round", 62, 35)
    s.prop("rock_pebbles_scatter", 55, 38)
    # southern wilds
    s.prop("bush_clover", 16, 55)
    s.prop("flowers_white", 16, 60)
    s.prop("bush_round", 39, 60)
    s.prop("flowers_white", 43, 61)
    s.prop("rock_pebbles_scatter", 47, 59)
    s.prop("bush_clover", 60, 44)
    s.prop("flowers_white", 66, 58)
    s.fill(41, 46, 42, 47, "grass_dark")
    s.fill(23, 45, 24, 46, "grass_dark")


def full_map():
    s = Scene(W, H, "grass")
    tree_frame(s)
    roads_and_river(s)
    well_crossroads(s)
    market_square(s)
    forge_quarter(s)
    fountain_garden_(s)
    village_gate_(s)
    churchyard_(s)
    orchard_(s)
    farmstead_(s)
    boulder_field_(s)
    south_wilds(s)
    life_scatter(s)
    return s


if __name__ == "__main__":
    s = full_map()
    img, issues = s.render(scale=3, strict=False)
    img.convert("RGB").save(os.path.join(OUT, "full_map.png"))
    view = img.convert("RGB")
    if view.width > 1900:
        f = 1900 / view.width
        view = view.resize((1900, int(view.height * f)), Image.LANCZOS)
    view.save(os.path.join(OUT, "_full_map_view.png"))
    print(f"full_map: {W}x{H}  [{'OK' if not issues else '; '.join(issues)}]")

"""Vila da Clareira — organic rural-medieval showcase (v2).

Rebuilt from critique: cottages are placed individually across the terrain (not
four identical lots on a rigid cross), each set back from a bending dirt road
with a kitchen garden / field fronting the lane. Nature (trees, hedgerows, rocks,
flowers) is spread over the open ground so it reads as lived-in countryside.

Also fixes three wrong catalog rects that were clipping sprites:
  house_large  col7 4x5 -> col6 5x5   (the 'incomplete house' — left wall clipped)
  barn_large   5x5      -> 5x6         (bottom door lip clipped)
  tent_wood    col13    -> col12       (left half clipped)
"""
from showcase import Map, save, slice_tile, CAT

# --- rect corrections (the 218-tile catalog mis-sized these) ---
CAT["house_large"].update(col=6, row=0, w=5, h=5)
CAT["barn_large"].update(col=11, row=0, w=5, h=6)
CAT["tent_wood"].update(col=12, row=5, w=2, h=3)

W, H = 84, 60


def scatter(m, spots, name):
    for (x, y) in spots:
        m.p(x, y, name)


def cottage(m, hx, hy, front="S", crop="crops_field"):
    """A single cottage set back from the lane with a fenced kitchen garden in
    front. house_large is a complete 5x5 sprite; we add a chimney and a garden."""
    m.p(hx, hy, "house_large")
    m.p(hx + 1, hy - 1, "chimney_stone")
    if front == "S":
        gx0, gy0, gx1, gy1 = hx, hy + 5, hx + 4, hy + 7
        fy = gy1 + 1
        for x in range(gx0, gx1 + 1):
            m.g(x, gy0, crop); m.g(x, gy0 + 1, crop)
        for x in range(gx0, gx1 + 1):
            m.p(x, fy, "fence_wood")
        m.p(hx + 2, fy, "fence_gate_frame")
        m.p(gx0, gy0, "planter_box"); m.p(gx1 - 1, gy0 + 1, "flowerpot_plant")
    elif front == "W":
        for y in range(hy + 1, hy + 5):
            m.g(hx - 3, y, crop); m.g(hx - 2, y, crop); m.g(hx - 1, y, crop)
        for y in range(hy, hy + 6):
            m.p(hx - 4, y, "fence_wood")
        m.p(hx - 4, hy + 2, "fence_gate_frame")
        m.p(hx - 1, hy + 1, "flowerpot_sprout")
    elif front == "E":
        for y in range(hy + 1, hy + 5):
            m.g(hx + 5, y, crop); m.g(hx + 6, y, crop); m.g(hx + 7, y, crop)
        for y in range(hy, hy + 6):
            m.p(hx + 8, y, "fence_wood")
        m.p(hx + 8, hy + 2, "fence_gate_frame")
        m.p(hx + 5, hy + 4, "planter_box")


def crop_field(m, x0, y0, x1, y1, crop="crops_field", gate_x=None):
    """A standalone fenced field with a gate on its south edge."""
    for y in range(y0, y1):
        for x in range(x0, x1 + 1):
            m.g(x, y, crop)
    for x in range(x0, x1 + 1):
        m.p(x, y1, "fence_wood")
    m.p(gate_x if gate_x is not None else (x0 + x1) // 2, y1, "fence_gate_frame")


def church(m, cx, cy):
    """Stone chapel: tiled roof flush on the walls, attached round bell tower."""
    m.p(cx, cy, "stone_wall_arch"); m.p(cx + 3, cy, "stone_wall_arch")
    m.p(cx, cy - 2, "roof_tile_large")
    m.p(cx + 2, cy + 1, "door_arch_stone")
    m.p(cx + 4, cy, "window_wood")
    m.p(cx + 1, cy - 2, "chimney_stone")
    m.p(cx + 6, cy - 2, "roof_round_orange")
    m.p(cx + 2, cy + 3, "stairs_stone")
    m.p(cx - 1, cy + 1, "door_barred")
    m.p(cx + 5, cy, "chain_hanging")


def build():
    m = Map(W, H)
    # gently varied grass so the ground isn't a flat sheet
    m.scatter(2, 2, W - 3, H - 3,
              ["grass_plain"] * 6 + ["grass_tuft", "grass_worn"], step=4, seed=13)
    # forest edging (denser in corners, thinner along the middle of each side)
    for x in range(0, W - 2, 3):
        m.p(x, 0, "tree_foliage"); m.p(x, H - 3, "tree_foliage")
    for y in range(3, H - 4, 3):
        m.p(0, y, "tree_foliage"); m.p(W - 3, y, "tree_foliage")

    # ---------------- North: ruined gate + watchtower (NW), quarry (NE) --------
    m.cliff_south(4, 22, 2)
    m.p(4, 0, "tower_stone_round"); m.p(9, 1, "castle_gate")
    m.p(14, 3, "stone_wall_arch")
    m.p(5, 0, "flag_blue"); m.p(11, 2, "banner_blue")
    m.cliff_south(56, 80, 2)
    m.p(60, 2, "cave_entrance"); m.p(77, 4, "cave_hole")
    m.p(66, 3, "coal_rocks"); m.p(70, 5, "boulder_large")
    m.p(63, 8, "rocks_row"); m.p(58, 8, "rock_small"); m.p(76, 11, "rock_small")
    m.g(72, 11, "cliff_rock_fill"); m.g(73, 12, "cliff_rock_fill")
    m.p(63, 11, "crate_wood"); m.p(64, 12, "planks_pile")

    # ---------------- Creek (slightly stepped) with the old stone bridge -------
    m.pond(6, 13, 43, 15, lilies=[(12, 14), (28, 14)])
    m.pond(42, 15, 78, 17, lilies=[(56, 16), (68, 16)])
    for (x, y) in [(20, 14), (62, 16)]:
        m.g(x, y, "water_deep")
    m.g(16, 13, "water_ripple"); m.g(70, 15, "water_fill")
    m.g(24, 15, "shore_grass_water"); m.g(34, 15, "pond_grass_edge")
    m.g(46, 17, "pond_sand_edge")                 # bright shore tiles only by water
    m.p(18, 16, "water_lilies_cluster")
    m.p(38, 9, "bridge_castle")
    m.p(48, 16, "tree_stumps"); m.p(52, 11, "tree_trunk_vertical")
    m.p(30, 16, "log_horizontal"); m.p(10, 16, "bush_round")

    # ---------------- Bending dirt roads (organic circulation) -----------------
    m.road_poly([(39, 57), (39, 48), (37, 42), (34, 37)], w=2)        # gate -> green
    m.road_poly([(35, 36), (39, 30), (40, 20), (40, 15)], w=2)        # green -> bridge
    m.road_poly([(41, 14), (44, 8), (47, 5)], w=2)                    # bridge -> quarry
    m.road_poly([(33, 38), (22, 40), (13, 43)], w=2)                  # west spur
    m.road_poly([(42, 33), (54, 31), (63, 33)], w=2)                  # east spur
    m.p(38, 56, "gate_arch_wood"); m.g(40, 55, "dirt_patch")
    m.p(37, 54, "signpost_tall")
    m.p(36, 50, "lamp_post"); m.p(42, 46, "lamp_post")

    # ---------------- Village green / commons (irregular, grassy) --------------
    m.p(27, 26, "tree_foliage")                   # shade oak north of the green
    m.g(37, 35, "cobblestone_path")               # small stone dais
    m.p(38, 35, "fountain_stone")
    m.p(33, 32, "well_stone"); m.p(33, 34, "fountain_basin")   # well + its trough
    m.p(42, 36, "bench_wood"); m.p(42, 32, "bench_wood")
    m.p(36, 31, "flag_blue"); m.p(30, 36, "banner_blue")
    m.p(31, 33, "lamp_post"); m.p(43, 34, "lamp_post")
    m.g(39, 39, "dirt_patch")
    # small monument garden on the open north edge of the green
    m.p(28, 39, "arch_stone")
    m.p(29, 41, "statue_relief"); m.p(31, 41, "statue_pawn")
    m.p(30, 43, "stone_slab_round")

    church(m, 14, 49)

    # ---------------- Cottages spread across the terrain -----------------------
    cottage(m, 8, 34, front="S", crop="crops_field")     # W, above the west spur
    cottage(m, 48, 22, front="S", crop="dirt_field_tilled")  # N-central
    cottage(m, 58, 24, front="W", crop="crops_field")    # E of the creek
    cottage(m, 66, 36, front="W", crop="crops_field")    # E, off the east spur
    cottage(m, 20, 30, front="E", crop="crops_field")    # NW of the green

    # ---------------- Standalone fields + hedgerows (open countryside) ---------
    crop_field(m, 50, 34, 56, 39, "crops_field", gate_x=53)
    crop_field(m, 6, 22, 12, 26, "dirt_field_tilled", gate_x=9)
    scatter(m, [(31, y) for y in range(43, 49)], "hedge_block")   # hedgerow by shrine
    scatter(m, [(x, 31) for x in range(60, 66)], "hedge_block")   # hedge by E cottage

    # ---------------- Orchard (rows of trees) ----------------------------------
    scatter(m, [(x, y) for y in (48, 52) for x in (52, 56, 60)], "tree_foliage")
    m.p(54, 45, "haystack")

    # ---------------- Working farmstead (SE corner, room to breathe) -----------
    m.p(66, 44, "barn_large")
    crop_field(m, 60, 52, 80, 57, "crops_field", gate_x=70)
    m.p(72, 43, "haystack"); m.p(62, 50, "haystack")
    m.p(73, 50, "sack_flour"); m.p(64, 50, "crate_wood")
    m.p(72, 45, "cellar_door_dark")
    m.p(76, 50, "trapdoor_closed"); m.p(78, 50, "trapdoor_open")
    m.p(60, 49, "planks_pile"); m.p(58, 43, "log_wall")
    m.p(59, 45, "door_wood")                      # tool-shed door under the log wall
    scatter(m, [(x, 51) for x in range(60, 66)], "palisade_log")

    # ---------------- Market day + travelling merchant (S of the green) --------
    m.p(24, 46, "market_stall_awning")
    m.p(25, 51, "market_table")
    m.row(24, 53, ["produce_crate_banana", "produce_crate_greens",
                   "produce_crate_tomato", "produce_crate_lemon"], gap=0)
    m.p(30, 48, "barrel_wood"); m.p(31, 50, "crate_x"); m.p(23, 51, "counter_wood")
    m.p(31, 52, "tent_wood"); m.p(34, 53, "stump_table")
    m.p(29, 55, "stool_wood"); m.p(30, 52, "crate_open")

    # ---------------- Smithy (east of the road) --------------------------------
    m.p(45, 42, "anvil_forge"); m.p(48, 41, "chimney_stone")
    m.p(44, 46, "planks_pile"); m.p(47, 46, "crate_wood"); m.p(49, 45, "barrel_wood")
    m.p(45, 39, "shingle_wall"); m.p(50, 43, "lantern_hanging")
    m.g(43, 45, "roof_tile_fill")

    # ---------------- Quiet ruin corner (SW) -----------------------------------
    m.g(4, 55, "grass_dark"); m.g(5, 56, "grass_dark"); m.g(6, 55, "grass_dark")
    m.p(3, 54, "bush_dead_grey"); m.p(6, 56, "tree_stumps")
    m.p(4, 57, "skull"); m.p(7, 57, "bone")

    # ---------------- Nature spread over the open ground -----------------------
    scatter(m, [(16, 22), (72, 28), (12, 47), (52, 20), (78, 44), (36, 22)], "bush_round")
    scatter(m, [(70, 22), (14, 20), (54, 26), (24, 50)], "rock_small")
    scatter(m, [(30, 20), (66, 20), (10, 30), (76, 34), (44, 20)], "flowers_white")
    scatter(m, [(58, 40), (18, 44)], "tree_foliage")
    m.p(52, 34, "grass_flower_yellow")            # one deliberate bright meadow patch
    m.p(64, 30, "rocks_row")
    return save(m, "A_full_vila_da_clareira.png")


if __name__ == "__main__":
    used = build()
    import json, os
    real = {e["name"] for e in json.load(
        open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          "catalog", "catalog.json"))) if e["sheet"] == "overworld"}
    missing = sorted(real - used)
    print(f"Overworld coverage: {len(used & real)}/{len(real)}")
    print("Missing:", ", ".join(missing) if missing else "none")

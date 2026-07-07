"""Three candidate outdoor showcase scenes, composed like ALttP overworld areas.

Each is a coherent *place* — framed by forest and cliffs, with paths connecting
buildings and natural water edges — not a grid of sample tiles. Run to emit PNGs
under gfx/previews/ for design approval.
"""
from showcase import Map, save, slice_tile


def forest_frame(m, thickness=2):
    """Ring the map edges with tree clumps + bushes so the play area reads framed."""
    W, H = m.w, m.h
    for x in range(0, W - 2, 3):
        m.p(x, 0, "tree_foliage")
        m.p(x, H - 3, "tree_foliage")
    for y in range(0, H - 2, 3):
        m.p(0, y, "tree_foliage")
        m.p(W - 3, y, "tree_foliage")
    for (x, y) in [(6, 1), (W - 8, 1), (2, H // 2), (W - 5, H // 2 - 4)]:
        m.p(x, y, "bush_round")


def meadow_texture(m, x0, y0, x1, y1):
    m.scatter(x0, y0, x1, y1, ["grass_plain", "grass_plain", "grass_tuft",
                               "grass_worn", "flowers_white"], step=4, seed=7)


# ---------------------------------------------------------------------------
# A — Vila da Clareira: a Kakariko-style village in a forest clearing.
# ---------------------------------------------------------------------------
def village():
    m = Map(66, 46)
    meadow_texture(m, 2, 2, 63, 43)
    forest_frame(m)
    # North escarpment with a cave, framing the top.
    m.cliff_south(10, 55, 2)
    m.p(30, 2, "cave_entrance")
    m.p(20, 1, "tree_trunk_vertical"); m.p(46, 1, "tree_stumps")

    # Gravel main road down the middle, widening into a plaza at the crossing.
    m.road_v(30, 6, 43, w=2)
    m.road_h(6, 60, 24, w=2)                     # cross street
    for yy in range(20, 28):                     # plaza apron
        for xx in range(26, 39):
            m.g(xx, yy, "gravel_light")
    m.g(30, 22, "cobblestone_path")             # decorative stone pad under fountain
    m.p(31, 22, "fountain_stone")               # plaza centrepiece
    m.p(24, 21, "well_stone")
    m.p(26, 20, "lamp_post"); m.p(38, 20, "lamp_post")
    m.p(26, 27, "lamp_post"); m.p(38, 27, "lamp_post")
    m.p(35, 25, "bench_wood"); m.p(24, 26, "signpost_tall")
    m.p(29, 18, "flag_blue"); m.p(34, 29, "banner_blue")

    # Houses facing the plaza/road, each with a fenced back garden.
    def cottage(hx, hy, garden="left"):
        m.p(hx, hy, "house_large")               # 4x5
        m.p(hx + 1, hy + 5, "door_wood")
        m.p(hx, hy - 1, "chimney_stone")
        m.p(hx + 3, hy + 4, "lantern_hanging")
        gx = hx - 5 if garden == "left" else hx + 5
        for i in range(4):
            m.g(gx + i, hy + 1, "dirt_field_tilled")
            m.g(gx + i, hy + 2, "dirt_field_tilled")
        m.p(gx, hy + 1, "crops_field")
        m.p(gx + 2, hy, "planter_box"); m.p(gx + 1, hy + 3, "flowerpot_plant")
        for i in range(5):
            m.p(gx - 1 + i, hy + 3, "fence_wood")
        m.p(gx + 1, hy + 3, "fence_gate_frame")

    cottage(12, 12, "left"); cottage(48, 12, "right"); cottage(14, 32, "left")
    # Foot-paths linking each doorway to the cross street / main road.
    m.road_path([(13, y) for y in range(18, 24)])       # NW cottage -> cross street
    m.road_path([(49, y) for y in range(18, 24)])       # NE cottage
    m.road_v(15, 26, 32, w=2)                            # SW cottage spur
    m.road_h(15, 30, 24)
    # Barn + farm on the SE.
    m.p(46, 30, "barn_large")
    m.p(45, 36, "haystack"); m.p(52, 33, "haystack")
    for i in range(5):
        m.g(44 + i, 40, "crops_field"); m.g(44 + i, 41, "dirt_field_tilled")

    # Market corner (SW) — stalls, tables, produce, barrels.
    m.p(6, 30, "market_stall_awning")
    m.p(7, 36, "market_table")
    m.row(6, 39, ["produce_crate_banana", "produce_crate_greens",
                  "produce_crate_tomato", "produce_crate_lemon"], gap=0)
    m.p(11, 35, "barrel_wood"); m.p(12, 35, "crate_wood"); m.p(13, 35, "sack_flour")
    m.p(10, 34, "counter_wood"); m.p(5, 38, "stool_wood")

    # Blacksmith by the road.
    m.p(38, 34, "anvil_forge"); m.p(41, 33, "chimney_stone")
    m.p(37, 37, "planks_pile"); m.p(40, 37, "crate_x")

    # A small pond with lilies to the west of the plaza.
    m.pond(3, 18, 8, 23, lilies=[(4, 19), (6, 21)])
    m.p(9, 17, "bush_round"); m.p(2, 24, "flowers_white")

    # Flower beds + hedges dressing the plaza edges.
    m.p(23, 18, "grass_flower_yellow"); m.p(40, 30, "grass_flower_yellow")
    m.p(28, 32, "hedge_block"); m.p(34, 16, "hedge_block")
    m.p(22, 32, "lamp_post"); m.p(42, 24, "flowerpot_sprout")
    return save(m, "A_vila_da_clareira.png")


# ---------------------------------------------------------------------------
# B — Portão de Hyrule: a castle gate approach with a moat and bridge.
# ---------------------------------------------------------------------------
def castle():
    m = Map(60, 48)
    meadow_texture(m, 2, 2, 57, 45)
    # Side cliffs frame the approach; cave in the east ridge.
    for y in (2, 5):
        m.cliff_south(2, 14, y) if y == 2 else None
    m.cliff_south(3, 20, 2)
    m.cliff_south(40, 56, 2)
    m.p(50, 2, "cave_entrance")
    forest_frame(m)

    # Castle wall + gate across the top, flanked by round towers.
    m.p(26, 3, "castle_gate")                    # 5x6
    m.p(18, 2, "tower_stone_round"); m.p(37, 2, "tower_stone_round")
    m.p(22, 4, "stone_wall_arch"); m.p(31, 4, "stone_wall_arch")
    m.p(20, 1, "flag_blue"); m.p(39, 1, "flag_blue")
    m.p(28, 9, "door_arch_stone"); m.p(19, 6, "door_barred")
    m.p(25, 3, "banner_blue"); m.p(34, 3, "banner_blue")
    m.p(28, 2, "chain_hanging")

    # Gravel causeway from the gate down through the courtyard to the bridge.
    m.road_v(28, 9, 23, w=3)
    for yy in range(11, 20):                     # formal courtyard apron
        for xx in range(22, 40):
            m.g(xx, yy, "gravel_light")
    m.g(29, 12, "cobblestone_path")             # stone dais under the fountain
    m.p(28, 16, "arch_stone")
    m.p(24, 12, "statue_pawn"); m.p(35, 12, "statue_pawn")
    m.p(22, 14, "statue_relief"); m.p(37, 14, "statue_relief")
    m.p(30, 12, "fountain_stone")
    m.p(23, 11, "lamp_post"); m.p(38, 11, "lamp_post")
    m.p(24, 18, "stairs_stone"); m.p(37, 18, "stairs_stone")
    m.p(26, 19, "stone_slab_round"); m.p(33, 19, "stone_slab_round")

    # The moat: a wide water band crossed by the castle bridge.
    m.pond(6, 24, 53, 28, lilies=[(10, 25), (44, 27), (18, 26)])
    m.g(48, 25, "water_deep"); m.g(12, 26, "water_ripple")
    m.p(27, 23, "bridge_castle")                 # 5x6 spans the moat
    m.p(48, 24, "water_lilies_cluster")

    # South approach: gravel road from the bridge down to the wooden outer gate.
    m.road_v(28, 29, 43, w=3)
    m.p(27, 42, "gate_arch_wood")
    m.road_h(10, 28, 40, w=2)                    # side lane to the guard camp
    m.p(6, 40, "palisade_log"); m.p(48, 40, "palisade_log")
    m.p(10, 34, "tent_wood"); m.p(14, 37, "signpost_tall")
    m.p(9, 38, "barrel_wood"); m.p(11, 38, "crate_wood")
    m.p(13, 33, "banner_blue")
    m.p(2, 30, "log_wall"); m.p(50, 33, "log_wall")
    m.p(44, 36, "well_stone"); m.p(43, 42, "bench_wood")

    # Overgrown graveyard corner (SW): ruin + bones.
    m.g(4, 44, "grass_dark"); m.g(5, 45, "grass_dark"); m.g(6, 44, "grass_dark")
    m.p(3, 43, "bush_dead_grey"); m.p(7, 44, "tree_stumps")
    m.p(4, 46, "skull"); m.p(6, 46, "bone")
    m.p(2, 20, "cellar_door_dark"); m.p(52, 44, "trapdoor_closed")
    return save(m, "B_portao_de_hyrule.png")


# ---------------------------------------------------------------------------
# C — Bosque Perdido & Lago: a Lost-Woods lake with a woodcutter's camp.
# ---------------------------------------------------------------------------
def woods():
    m = Map(66, 48)
    meadow_texture(m, 2, 2, 63, 45)
    forest_frame(m, thickness=2)
    # Extra inner forest masses to make a maze-like Lost Woods feel.
    for (x, y) in [(10, 6), (16, 4), (44, 4), (52, 8), (8, 20), (58, 22),
                   (12, 38), (48, 40), (56, 38), (22, 8), (38, 6)]:
        m.p(x, y, "tree_foliage")
    for (x, y) in [(20, 12), (48, 14), (30, 40), (60, 30), (6, 30)]:
        m.p(x, y, "bush_round")
    m.p(24, 6, "hedge_block"); m.p(50, 20, "hedge_block")

    # Rocky ridge across the NE with a cave + cave-hole + boulder.
    m.cliff_south(38, 62, 3)
    m.p(45, 3, "cave_entrance")
    m.p(55, 3, "cave_hole")
    m.p(51, 9, "boulder_large")                  # 5x6
    m.p(40, 10, "coal_rocks"); m.p(58, 11, "rocks_row")
    m.p(44, 13, "rock_small"); m.p(60, 14, "rock_small")

    # The lake (SW quadrant) with lily clusters + reedy shore.
    m.pond(6, 26, 26, 42, lilies=[(9, 29), (14, 34), (20, 31), (11, 38)])
    m.g(10, 30, "water_deep"); m.g(18, 36, "water_deep")
    m.g(22, 28, "water_ripple")
    m.p(8, 27, "water_lilies_cluster"); m.p(23, 39, "water_lily")
    # Logged shoreline: felled trunks + stumps.
    m.p(4, 24, "tree_trunk_vertical"); m.p(28, 40, "tree_stumps")
    m.p(27, 34, "log_horizontal")

    # A single continuous gravel trail winding camp -> lakeshore -> up to the cave.
    trail = [(35, 44), (35, 43), (34, 42), (34, 41), (33, 40), (33, 39), (32, 38),
             (31, 37), (30, 36), (29, 35), (28, 34), (28, 33),          # to lakeshore
             (30, 32), (32, 31), (34, 30), (36, 29), (38, 28), (40, 26),
             (42, 24), (43, 22), (44, 20), (45, 18), (46, 16), (46, 14),
             (46, 12), (46, 10)]                                        # up to the cave
    m.road_path(trail)

    # Woodcutter's camp clearing (S centre).
    m.p(34, 34, "tent_wood")
    m.p(38, 36, "stump_table"); m.p(41, 37, "stool_wood"); m.p(37, 39, "stool_wood")
    m.p(42, 34, "log_wall"); m.p(31, 40, "palisade_log")
    m.p(44, 40, "crate_open"); m.p(46, 40, "barrel_wood"); m.p(45, 42, "planks_pile")
    m.p(48, 36, "haystack"); m.p(33, 43, "signpost_tall")
    m.p(39, 43, "stone_slab_round")              # campfire ring
    m.p(36, 33, "log_horizontal")
    m.p(43, 32, "lantern_hanging"); m.p(30, 37, "banner_blue")

    # Wildflower meadow (SE) + a half-buried ruin.
    for (x, y) in [(52, 44), (56, 42), (58, 46), (54, 40)]:
        m.p(x, y, "grass_flower_yellow")
    m.p(60, 40, "arch_stone"); m.p(62, 44, "statue_relief")
    m.p(59, 45, "bush_dead_grey"); m.p(57, 45, "skull"); m.p(61, 46, "bone")
    m.p(50, 46, "flowerpot_sprout")
    return save(m, "C_bosque_perdido_lago.png")


if __name__ == "__main__":
    used = set()
    for fn in (village, castle, woods):
        used |= fn()
    from showcase import CAT
    catalog_names = {n for n, e in CAT.items() if "col" in e}
    # Only report against the real 92-tile overworld catalog (exclude vocab extras).
    import json, os
    real = {e["name"] for e in json.load(
        open(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                          "catalog", "catalog.json"))) if e["sheet"] == "overworld"}
    missing = sorted(real - used)
    print(f"\nCombined overworld coverage: {len(used & real)}/{len(real)}")
    print("Not yet placed:", ", ".join(missing) if missing else "none")

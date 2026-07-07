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


SCENES = {"pond": pond, "path_demo": path_demo, "churchyard": churchyard}

if __name__ == "__main__":
    for n in (sys.argv[1:] or list(SCENES)):
        build(n, SCENES[n]())

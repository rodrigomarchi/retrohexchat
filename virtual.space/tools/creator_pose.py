"""The posed clips of the Space character creator (sit, wave, dance), as skeletons.

PixelLab has no "sit", "wave" or "dance" animation template, and a pose drawn
freely differs from one piece to the next, so the pieces of a character would
not line up. Those clips are therefore *posed*: the master mannequin's 3-D skeleton
(which PixelLab estimates and keeps with the character) is bent into the
clip's poses here, projected into each of the eight facings, and sent to
`animate-with-skeleton-v3` for every piece with the very same keypoints.

The projection of a facing is not published, but PixelLab also keeps a 2-D
skeleton per facing; an affine map 3-D -> 2-D fitted to those 18 joints lands
within a pixel or two, which is all a pose needs.

Coordinates are PixelLab's: 3-D x across the body, y depth (the face looks
towards smaller y), z up; 2-D x and y as fractions of the image.
"""
from __future__ import annotations

UPPER = ("NECK", "NOSE", "LEFT EAR", "RIGHT EAR", "LEFT EYE", "RIGHT EYE",
         "LEFT SHOULDER", "RIGHT SHOULDER", "LEFT HIP", "RIGHT HIP")
SEAT_DROP = 0.20  # how far the hips sink, as a fraction of the figure's height


def _solve(a, b):
    """Solve the square system a·x = b by Gaussian elimination with pivoting."""
    n = len(a)
    m = [list(row) + [b[i]] for i, row in enumerate(a)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda r: abs(m[r][col]))
        if abs(m[pivot][col]) < 1e-12:
            raise ValueError("singular system")
        m[col], m[pivot] = m[pivot], m[col]
        for r in range(n):
            if r != col:
                f = m[r][col] / m[col][col]
                m[r] = [x - f * y for x, y in zip(m[r], m[col])]
    return [m[i][n] / m[i][i] for i in range(n)]


def fit_projection(points3, points2):
    """Least-squares affine map 3-D -> 2-D: returns rows (ax, ay) of 4 terms each,
    so that x2 = ax·[x, y, z, 1] and y2 = ay·[x, y, z, 1]."""
    rows = [list(p) + [1.0] for p in points3]
    ata = [[sum(r[i] * r[j] for r in rows) for j in range(4)] for i in range(4)]
    out = []
    for axis in range(2):
        atb = [sum(r[i] * q[axis] for r, q in zip(rows, points2)) for i in range(4)]
        out.append(_solve(ata, atb))
    return out


def project(point3, projection):
    v = list(point3) + [1.0]
    return tuple(sum(c * x for c, x in zip(row, v)) for row in projection)


def _lerp(a, b, t):
    return [x + (y - x) * t for x, y in zip(a, b)]


def seated(standing, t):
    """The standing 3-D skeleton `standing` ({label: [x, y, z]}) a fraction `t`
    of the way down into a chair: hips sink, thighs come level and forward,
    shins hang straight, hands come to rest on the thighs."""
    drop = SEAT_DROP * t
    pose = {label: list(xyz) for label, xyz in standing.items()}
    for label in UPPER:
        pose[label][2] -= drop
    for side in ("LEFT", "RIGHT"):
        hip = pose[f"{side} HIP"]
        thigh = standing[f"{side} HIP"][2] - standing[f"{side} KNEE"][2]
        knee0, ankle0 = standing[f"{side} KNEE"], standing[f"{side} LEG"]
        knee1 = [knee0[0], hip[1] - thigh, hip[2] + 0.01]
        ankle1 = [ankle0[0], knee1[1] + 0.02, ankle0[2]]
        pose[f"{side} KNEE"] = _lerp(knee0, knee1, t)
        pose[f"{side} LEG"] = _lerp(ankle0, ankle1, t)
        inward = 0.03 if side == "RIGHT" else -0.03
        wrist0 = standing[f"{side} ARM"]
        wrist_down = [wrist0[0], wrist0[1], wrist0[2] - drop]
        pose[f"{side} ARM"] = _lerp(wrist_down, [wrist0[0] + inward, hip[1] - 0.10, hip[2] + 0.03], t)
        elbow0 = standing[f"{side} ELBOW"]
        elbow_down = [elbow0[0], elbow0[1], elbow0[2] - drop]
        pose[f"{side} ELBOW"] = _lerp(elbow_down, [elbow0[0], elbow0[1] - 0.04, elbow0[2] - drop], t)
    return pose


def _limb(origin, direction, length):
    """The point `length` from `origin` along `direction` (any non-zero vector)."""
    norm = sum(c * c for c in direction) ** 0.5
    return [o + c * length / norm for o, c in zip(origin, direction)]


def _arm(pose, standing, side, upper, lower):
    """Point one arm: the upper arm along `upper`, the forearm along `lower`,
    each keeping its standing length."""
    shoulder = pose[f"{side} SHOULDER"]
    upper_len = _distance(standing[f"{side} SHOULDER"], standing[f"{side} ELBOW"])
    lower_len = _distance(standing[f"{side} ELBOW"], standing[f"{side} ARM"])
    pose[f"{side} ELBOW"] = _limb(shoulder, upper, upper_len)
    pose[f"{side} ARM"] = _limb(pose[f"{side} ELBOW"], lower, lower_len)


def _distance(a, b):
    return sum((x - y) ** 2 for x, y in zip(a, b)) ** 0.5


def _outward(side):
    """+1 or -1: which way along x is away from the body for a side (the
    figure's right is at smaller x)."""
    return -1.0 if side == "RIGHT" else 1.0


def waving(standing, step):
    """The right hand raised in a wave. `step` below 1 is the way up (0 at the
    side, 1 raised); 1 is the hand out, 2 the hand in, so 1, 2, 1, 2 waves."""
    pose = {label: list(xyz) for label, xyz in standing.items()}
    out = _outward("RIGHT")
    if step < 1:
        # Halfway: the upper arm out and level-ish, the forearm rising.
        t = step
        _arm(pose, standing, "RIGHT", [out * (0.2 + 0.6 * t), -0.1, -1.0 + 1.5 * t], [out * 0.3, -0.2, -1.0 + 2.0 * t])
        return pose
    # Out to the side and a little forward, so that seen side-on the hand is
    # in front of the face, not over the head.
    tilt = 0.6 if step == 1 else -0.3
    _arm(pose, standing, "RIGHT", [out * 0.7, -0.45, 0.55], [out * tilt, -0.35, 1.0])
    return pose


def dancing(standing, beat):
    """A four-beat dance: 0 the right arm up and the left hand on the hip, the
    body swaying right and the knees bent; 2 the same mirrored; 1 and 3
    upright with both elbows out at the chest."""
    pose = {label: list(xyz) for label, xyz in standing.items()}
    beat = int(beat) % 4
    if beat in (1, 3):
        for side in ("LEFT", "RIGHT"):
            out = _outward(side)
            _arm(pose, standing, side, [out * 0.9, -0.3, -0.25], [-out * 0.6, -0.5, 0.65])
        return pose
    up, hip = ("RIGHT", "LEFT") if beat == 0 else ("LEFT", "RIGHT")
    sway = 0.018 * _outward(up)
    drop = 0.025
    for label in pose:
        if label in UPPER or label.endswith("ELBOW") or label.endswith("ARM"):
            pose[label][0] += sway
            pose[label][2] -= drop
    for side in ("LEFT", "RIGHT"):  # bent knees, feet where they stood
        pose[f"{side} KNEE"][1] -= 0.03
        pose[f"{side} KNEE"][2] -= drop / 2
        pose[f"{side} KNEE"][0] += sway / 2
    _arm(pose, standing, up, [_outward(up) * 0.35, -0.1, 1.0], [_outward(up) * 0.3, -0.05, 1.0])
    _arm(pose, standing, hip, [_outward(hip) * 0.8, 0.1, -0.6], [-_outward(hip) * 0.7, -0.1, -0.6])
    return pose


# A posed clip names its pose; each comes with the action the generation is
# told about, which keeps the model from drawing what the pose suggests.
POSES = {
    "seated": (seated, "sitting down, alone, with no chair, no table and no furniture drawn"),
    "wave": (waving, "waving hello with the right hand raised, standing alone, nothing held"),
    "dance": (dancing, "dancing happily on the spot, standing alone, nothing held"),
}


def keypoints_2d(pose3, projection, scale=1.0, offset=0.0):
    """A pose as the 18-joint keypoint list `animate-with-skeleton-v3` takes.

    `scale` and `offset` move fractions of the character's own canvas onto a
    larger canvas it is centred in (e.g. 104 px inside 144: scale 104/144,
    offset 20/144)."""
    out = []
    for label in sorted(pose3):
        x, y = project(pose3[label], projection)
        x, y = x * scale + offset, y * scale + offset
        out.append({"label": label, "x": min(1.0, max(0.0, x)), "y": min(1.0, max(0.0, y))})
    return out


def posed_clip(skeletons, direction, pose, steps, scale=1.0, offset=0.0):
    """(first-frame keypoints, per-step keypoints) for one facing of a posed
    clip: `pose` names an entry of POSES, `steps` its argument per frame.

    `skeletons` is the `skeletons` object of a PixelLab character: `3d` holds
    the standing pose, `2d_references[direction]` the 2-D skeleton of the
    facing's rotation image (the first frame)."""
    standing = {label: list(v[:3]) for label, v in skeletons["3d"]["keypoints"].items()}
    reference = skeletons["2d_references"][direction]["keypoints"]
    labels = sorted(standing)
    projection = fit_projection([standing[l] for l in labels],
                                [(reference[l]["x"], reference[l]["y"]) for l in labels])
    first = [{"label": l, "x": reference[l]["x"] * scale + offset, "y": reference[l]["y"] * scale + offset}
             for l in labels]
    shape = POSES[pose][0]
    frames = [keypoints_2d(shape(standing, t), projection, scale, offset) for t in steps]
    return first, frames

---
name: virtual-space-art
description: Generating, importing and debugging virtual-space pixel art — characters, avatars, animations, isometric scenes, maps and props via the PixelLab pipeline. Use when creating or reworking a scene, adding or regenerating an avatar, animating tiles or props, or when generated art looks wrong in-game.
---

# Virtual-space art pipeline

The playbooks below are hard-won empirical knowledge: the PixelLab service and this
engine both have behaviour you cannot infer from the code. Read the one that matches
the task **before** generating anything — a wrong generation costs credits and time.

| Task | Read |
|---|---|
| Create or rework a scene / map | [`virtual.space/SCENES.md`](../../../virtual.space/SCENES.md) |
| Add, regenerate or debug a player avatar | [`virtual.space/CHARACTERS.md`](../../../virtual.space/CHARACTERS.md) |
| Animate tiles, props or scene FX | [`virtual.space/ANIMATIONS.md`](../../../virtual.space/ANIMATIONS.md) |
| Build a true isometric, 3D-reading scene | [`virtual.space/ISOMETRIC.md`](../../../virtual.space/ISOMETRIC.md) |
| Chase a real game's look (reference material) | [`virtual.space/DISCOVERY.md`](../../../virtual.space/DISCOVERY.md) |

## Non-negotiables

These hold regardless of which playbook applies:

- **Art is native 1:1 and renders at scale 1.** A wrong size is fixed by
  **regenerating in PixelLab**, never by scaling or cropping in code. PixelLab is
  the source of truth for art.
- **Never deform aspect ratio.** Do not stretch or squash generated art to fit a
  slot — regenerate at the native ratio (`tile_height`, `width`×`height`).
  Deformation reads as low quality up close.
- **Premium quality, not the cheapest path.** Use PixelLab v3/pro (8-direction,
  highest quality); never `standard`. Credits are not the constraint.
- **Preserve ground truth as archaeology.** When a scene chases real reference
  material, commit the pixels into the repo *and* log source, anatomy and gaps in
  `DISCOVERY.md`. Never leave only a bare link.
- **The generated zip is the ground truth** when QA-ing animations: compare by
  sha1 against the PixelLab group zip rather than trusting the in-game render.

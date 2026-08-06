@AGENTS.md

# Claude Code

`AGENTS.md` above is the canonical instruction set, shared with every other agent.
This section is only what is specific to Claude Code.

## Path-scoped rules load themselves

`.claude/rules/` carries the conventions that only matter for part of the tree.
They load when you touch a matching file, so they are not repeated here:

| Rule | Fires on |
|---|---|
| `i18n.md` | `config/i18n_locales.exs`, `scripts/i18n/**`, `**/*.po`, gettext, JS catalogs |
| `css-svg.md` | `apps/retro_hex_chat_web/lib/**`, `assets/css/**` |
| `assets-js.md` | `apps/retro_hex_chat_web/assets/js/**` |
| `testing.md` | `**/test/**`, `**/*_test.exs`, `**/*.test.js` |
| `help-topics.md` | commands, LiveViews, components, `help_topics.ex` |

If a rule did not fire, you have not read a file it is scoped to. Read the file
first, or open the rule directly.

## Skills

- `virtual-space-art` — the PixelLab pipeline for scenes, avatars, animations and
  isometric maps. Loads on demand; the playbooks stay in `virtual.space/`.

## Working preferences

- **Use plan mode** for changes spanning more than one bounded context, and for
  anything touching WebRTC signaling or the deploy path.
- **Validate targeted while iterating, full `make ci` at the end of a functional
  block** — not after every edit.
- **Every error found is yours to fix now**, regardless of which session introduced it.
- **Debug browser behaviour with a targeted Playwright spec**, not an interactive
  browser session.

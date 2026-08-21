---
paths:
  - "apps/retro_hex_chat_web/lib/**/*.ex"
  - "apps/retro_hex_chat_web/lib/**/*.heex"
  - "apps/retro_hex_chat_web/assets/css/**"
---

# CSS & SVG architecture (enforced by `make ci` → CSS lint)

All styling uses **Tailwind CSS** via `retrohex.css` (entry point).
UI components live in `components/ui/` and use Tailwind utility classes.

## No hardcoded colors or CSS values in Elixir/JS

- **NEVER** put hex colors (`#fff`, `#3a3500`) in Elixir code — colors live in CSS only
- Use Tailwind classes or CSS custom properties for dynamic values
- Inline `style=` is acceptable ONLY for dynamic `left`/`top` positioning and CSS custom properties
- `make ci` enforces `mix audit.styles --strict` through CSS lint — it must show 0 LOW, 0 MEDIUM, 0 HIGH findings
- Exception: `log_exporter.ex` embeds CSS for standalone HTML exports (must stay self-contained)

The auditor reads **any** `#` followed by digits as a hex colour, including a
GitHub issue reference in a JS comment — `#3639` broke the build once. Write issue
references out in words.

## No inline SVGs

**NEVER** write inline `<svg>` tags in LiveViews, components, templates, or layouts.
All SVGs MUST live in dedicated modules. The CSS lint (`make lint.css`) enforces this.

**Icons → `RetroHexChatWeb.Icons` facade.** Icons are function components in
submodules under `components/icons/`, chosen by **what the icon depicts**, not by
where they are used. Adding one:

1. Choose the submodule by subject (`ls` the directory — it is the catalog)
2. Add `attr :class, :any, default: nil` + `@spec` + `~H""" <svg> """`
3. Add one line to `components/icons/registry.ex`
4. Use `<Icons.icon_name />` in templates (or `<.icon_name />` if imported)

**Pages carry a reference, not the drawing.** `mix retrohex.icons.sprite` renders
every registered icon into `priv/static/assets/icons/sprite.svg` at build time
(first step of `assets.build`/`assets.deploy`, before `phx.digest`), and the
facade emits `<svg class={@class}><use href="…/sprite.svg#icon_name" /></svg>`.
The sprite is generated, never committed. Skip the registry line and the icon has
no `<symbol>` to point at — `test/retro_hex_chat_web/components/icons_registry_test.exs`
catches that.

Root attributes that carry geometry or rendering hints (`viewBox`,
`shape-rendering`) move into the `<symbol>`; `class` and `aria-hidden` stay at the
call site. So an icon must be a **single flat `<svg>`** — no nested `<svg>`, no
`id=`, no `<defs>`/gradient/`filter`/`mask`/`url(#…)`, which would collide across
344 symbols in one document. `currentColor` is fine; it inherits through `<use>`.
The sprite task fails the build rather than emitting a broken symbol.

CSS may style the outer `<svg>` (`.window-title-meta svg`, `> svg`) but never its
children — they live in the `<use>` shadow tree and no selector reaches them.

**Naming:** `icon_<name>`, `icon_btn_<name>` (buttons), `icon_dialog_<name>` (title bars), `icon_tab_<name>` (tabs), `icon_group_<name>` (32×32 groups), `icon_fmt_<name>` (formatting), `icon_game_<name>` (games)

**Sizes:** 32×32 (desktop/game), 16×16 (toolbar/tab/dialog), 14×14 (formatting)

A missing icon is a real prerequisite — add it via submodule + facade
`defdelegate` + `@spec` first. Reuse before adding.

**Diagrams → `RetroHexChatWeb.Components.Diagrams`.** Complex SVG illustrations
(flowcharts, architecture diagrams, mockups) go in `components/diagrams.ex`.
Same pattern: `attr :class` + `@spec` + `~H""" <svg> """`.

**Exception:** `log_exporter.ex` embeds CSS/SVG for standalone HTML exports.

## Catalog

There is no hand-written inventory — a list of icons rots the week it is written.
The submodules under `components/icons/` **are** the catalog: `ls` them, grep them,
or visit `/showcase/icons` (dev only) to browse every icon visually.
`components/icons/registry.ex` is the index of which submodule draws what.

## JS visual state

JS that toggles visual state flips a CSS-owned project class (e.g.
`menubar-copy-disabled`), never raw Tailwind utilities, because the CSS lint scans
`classList.*` strings. Emit boolean-ish `data-*` attributes as explicit
`"true"`/`"false"` strings — hooks/CSS compare against the string.

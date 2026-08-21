defmodule RetroHexChatWeb.Icons do
  @moduledoc """
  Pixel-art SVG icon library for RetroHexChat's retro interface.

  This module is a **facade**: `Icons.icon_folder(assigns)` is the only way
  anything renders an icon. The drawing itself lives in a subject-based
  submodule under `RetroHexChatWeb.Icons.*`, and `mix retrohex.icons.sprite`
  collects all of them into one cached sprite at build time. What the facade
  emits is a reference into it:

      <svg class={@class} aria-hidden="true"><use href="…/sprite.svg#icon_folder" /></svg>

  So a page carries each icon as a pointer rather than as its shapes. `/connect`
  used to inline 169 drawings of which 94 were distinct; the sprite holds each
  one once and the browser reuses it across every page in the session.

  `RetroHexChatWeb.Icons.Registry` is the index that keeps the two halves
  honest — the facade generates a component per entry, the sprite task renders
  the art behind the same entry.

  ## Submodule Index

  | Module           | Subject                                       |
  |------------------|-----------------------------------------------|
  | `Icons.People`   | Users, contacts, social                       |
  | `Icons.Communication` | Chat, channels, networking               |
  | `Icons.Media`    | Audio, video, devices, quality                |
  | `Icons.CallControls` | 64x64 P2P/conference video controls      |
  | `Icons.Files`    | Documents, folders, clipboard                 |
  | `Icons.Hardware` | Servers, databases, platforms                 |
  | `Icons.Code`     | Terminal, scripting, automation               |
  | `Icons.Security` | Locks, shields, bans, privacy                 |
  | `Icons.Arrows`   | Directional arrows, navigation                |
  | `Icons.Marks`    | Checkmarks, X marks, status indicators        |
  | `Icons.Tools`    | Settings, editing, search, colors             |
  | `Icons.Alerts`   | Notifications, info, warnings                 |
  | `Icons.Symbols`  | Currency, stars, misc abstract symbols        |
  | `Icons.Formatting` | Text formatting (bold, italic, color, etc.) |
  | `Icons.Games`    | P2P game icons (32×32 pixel art)              |
  | `Icons.Flags`    | Language flags for the locale menu (14×14)    |

  ## Icon Sizes

  - **32×32** — desktop-style icons (folder, lock, notepad, trash, game icons)
  - **16×16** — toolbar, tab, button, and dialog title bar icons
  - **14×14** — formatting toolbar icons (bold, italic, etc.)

  ## SVG Template

  The art in the submodules is authored as a whole document:

      <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
        <!-- paths, rects, circles, etc. -->
      </svg>

  The sprite task keeps the root attributes that carry geometry and rendering
  hints — `viewBox`, `shape-rendering` — and drops `class` and `aria-hidden`,
  which belong to the `<svg>` the facade emits at the call site. Every icon
  takes an optional `:class` (default `nil`), a string or a list HEEx will join.

  ## Color Palette

  | Color     | Hex       | Usage                          |
  |-----------|-----------|--------------------------------|
  | Black     | `#000`    | Outlines, strokes              |
  | White     | `#fff`    | Highlights, dialog icon fills  |
  | Navy      | `#000080` | Primary brand color            |
  | Teal      | `#008080` | Accent                         |
  | Gray      | `#808080` | Secondary, muted elements      |
  | Silver    | `#C0C0C0` | Fills, backgrounds             |
  | Dark gray | `#555`    | Subtle strokes                 |
  | Light gray| `#DFDFDF` | Inner light bevels, contents   |
  | Gold      | `#FFD700` | Alerts, accents, folder fills  |
  | Red       | `#FF0000` | Danger, errors, close actions  |
  | Green     | `#008000` | Success, active, confirm       |

  ## Retro 3D / Win95 Pixel Art Style Guidelines

  We strictly follow a retro 90s OS aesthetic for all icons and diagrams.

  1. **Anti-Aliasing Off:** Use `shape-rendering="crispEdges"` on the `<svg>` tag for 16x16 icons and UI components, ensuring hard, pixelated edges.
  2. **16x16 vs 32x32:**
     - **16x16**: Strict pixel art. Use `<rect>` and `<polyline>` snapped to integer grids.
     - **32x32**: Classic vector clipart. Can use curves and anti-aliasing (no crispEdges), but with solid fills and thick hard strokes.
  3. **3D Bevel / Relevo:** Create visual depth manually using 1px strokes.
     - *Outset* (Buttons, Windows): White (`#fff`) or light gray (`#dfdfdf`) on Top/Left. Dark gray (`#808080`) or Black (`#000`) on Bottom/Right.
     - *Inset* (Inputs, Sunken content): Dark gray (`#808080`) or Black (`#000`) on Top/Left. White (`#fff`) or light gray (`#dfdfdf`) on Bottom/Right.
  4. **High Contrast:** Important geometries should have a solid black outline (`#000`, `stroke-width="1"` or `1.5`).
  5. **Drop Shadows:** Use solid black (`#000`) rectangles offset by 2-4px, without blur, underneath prominent floating elements.
  6. **Geometries:** Avoid `stroke-linecap="round"`. Prefer harsh geometric cuts.

  ## Contrast Rules

  - **Gray background** (toolbar, tabs, buttons): use navy (`#000080`),
    dark colors, and the full palette above.
  - **Dark background** (dialog title bars): use `#fff` as primary,
    `#FFD700` gold as accent, `#FF0000` red for danger, `#008000` green
    for success. Avoid dark fills that disappear against the gradient.

  ## Naming Convention

  - `icon_<name>` — standalone icons (toolbar, footer, misc)
  - `icon_btn_<name>` — button context (gray background)
  - `icon_tab_<name>` — tab context (gray background)
  - `icon_dialog_<name>` — dialog title bar (dark background)

  ## Adding an Icon

  1. Choose the correct submodule by **what the icon depicts**.
  2. Add `attr :class, :any, default: nil` before the function.
  3. Add `@spec icon_name(map()) :: Phoenix.LiveView.Rendered.t()`.
  4. Write the function with a `~H` sigil containing the SVG.
  5. Add one line to `RetroHexChatWeb.Icons.Registry` — without it the icon has
     no `<symbol>` in the sprite and no component here.
  6. Run `mix retrohex.icons.sprite` and `mix compile --warnings-as-errors`.
  """
  use Phoenix.Component

  alias RetroHexChatWeb.Icons.Registry
  alias RetroHexChatWeb.Icons.Sprite

  attr :name, :atom, required: true
  attr :class, :any, default: nil

  # The one shape every icon renders as. `Map.put/3` rather than `assign/3` on
  # the way in, for two reasons: the mobile menu drawer reaches an icon by name
  # with `apply(Icons, fn, [%{class: "…"}])`, a bare map that `assign/3` refuses;
  # and `:name` is fixed per component, so marking it changed on every update
  # would put a URL that never moves into every diff.
  defp sprite_ref(assigns) do
    ~H"""
    <svg class={@class} aria-hidden="true"><use href={Sprite.href(@name)} /></svg>
    """
  end

  # One component per registered icon, all of the same shape: the drawing lives
  # in the sprite and the page carries a reference to it. Written as a loop
  # rather than 344 near-identical functions so an icon cannot drift out of
  # step with the sprite that has to contain it.
  for {name, _module} <- Registry.all() do
    # `:any` rather than `:string` because call sites compose sizing with a
    # conditional colour — `class={["h-4 w-4", @muted && "text-warning"]}` —
    # and HEEx joins that list itself.
    attr :class, :any, default: nil

    @spec unquote(name)(map()) :: Phoenix.LiveView.Rendered.t()
    def unquote(name)(assigns) do
      assigns |> Map.put(:name, unquote(name)) |> sprite_ref()
    end
  end

  attr :locale, :string, required: true
  attr :class, :any, default: nil

  @doc """
  The flag for a locale, for the language menu. Unknown locales get a globe.
  """
  @spec flag_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def flag_icon(assigns) do
    assigns |> Map.put(:name, Registry.flag(assigns.locale)) |> sprite_ref()
  end

  attr :game_id, :string, required: true
  attr :class, :any, default: nil

  @doc """
  The box art for a game. Unknown ids get a generic cartridge.
  """
  @spec game_icon(map()) :: Phoenix.LiveView.Rendered.t()
  def game_icon(assigns) do
    assigns |> Map.put(:name, Registry.game(assigns.game_id)) |> sprite_ref()
  end
end

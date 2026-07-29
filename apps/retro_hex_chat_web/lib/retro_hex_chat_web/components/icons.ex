defmodule RetroHexChatWeb.Icons do
  @moduledoc """
  Pixel-art SVG icon library for RetroHexChat's retro interface.

  This module is a **facade** — every public function delegates to a
  subject-based submodule under `RetroHexChatWeb.Icons.*`. Consumers
  call `Icons.icon_folder(assigns)` exactly as before; the split is
  an internal implementation detail.

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

      <svg class={@class} viewBox="0 0 16 16" shape-rendering="crispEdges" aria-hidden="true">
        <!-- paths, rects, circles, etc. -->
      </svg>

  Every icon function accepts a single `assigns` map with an optional
  `:class` attribute (default `nil`). All SVGs use `aria-hidden="true"`.
  Most 16x16 SVGs use `shape-rendering="crispEdges"` to guarantee the retro pixel-art aesthetic.

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
  2. Add `attr :class, :string, default: nil` before the function.
  3. Add `@spec icon_name(map()) :: Phoenix.LiveView.Rendered.t()`.
  4. Write the function with a `~H` sigil containing the SVG.
  5. Add a `defdelegate` in this facade module.
  6. Run `mix compile --warnings-as-errors` to verify.
  """
  use Phoenix.Component
  use Gettext, backend: RetroHexChatWeb.Gettext

  # ── People ──────────────────────────────────────────────
  defdelegate icon_community(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_connect(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_robot(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_dialog_address_book(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_dialog_nick(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_tab_contacts(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_role_owner(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_role_operator(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_role_halfop(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_role_voiced(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_role_regular(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_status_user(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_dialog_profile(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_btn_profile(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_dialog_user_modes(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_btn_user_modes(assigns), to: RetroHexChatWeb.Icons.People
  defdelegate icon_tab_nicklist(assigns), to: RetroHexChatWeb.Icons.People

  # ── Communication ───────────────────────────────────────
  defdelegate icon_p2p(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_p2p_route(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_protocol_p2p(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_protocol_conference(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_protocol_p2p_compact(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_protocol_conference_compact(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_chat(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_channels(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_globe(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_websocket(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_webrtc(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_megaphone(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_send(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_link(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_dialog_invite(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_dialog_url(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_dialog_autojoin(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_autojoin(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_tab_channel(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_tab_pm(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_tab_conversations(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_disconnect(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_connect_lightning(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_connect_disabled(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_channel_list(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_toggle_conversations(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_toggle_nicklist(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_auto_respond(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_url_catcher(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_channel_central(assigns), to: RetroHexChatWeb.Icons.Communication

  # ── Media ───────────────────────────────────────────────
  defdelegate icon_conference(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_microphone(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_raise_hand(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_camera(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_camera_off(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_screen_share(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_mute(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_phone_end(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_layout_focus(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_layout_side_by_side(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_layout_maximize(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_pip(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_upgrade_video(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_devices(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_quality_high(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_quality_medium(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_quality_low(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_dialog_sound(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_btn_sounds(assigns), to: RetroHexChatWeb.Icons.Media

  # -- CallControls: P2P/conference video windows --
  defdelegate icon_call_microphone(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_mute(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_camera(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_camera_off(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_screen_share(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_phone_end(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_pip(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_devices(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_layout_auto(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_layout_focus(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_layout_split(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_layout_speaker(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_layout_compact(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_self_view(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_stats(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_mini(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_expand(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_webrtc(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_reactions(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_more(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_raise_hand(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_participants(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_lock(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_close(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_reaction_heart(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_reaction_thumbs_up(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_reaction_clap(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_reaction_laugh(assigns), to: RetroHexChatWeb.Icons.CallControls
  defdelegate icon_call_reaction_sparkle(assigns), to: RetroHexChatWeb.Icons.CallControls

  # ── Files ───────────────────────────────────────────────
  defdelegate icon_folder(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_notepad(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_trash(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_backup(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_file_send(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_choose_file(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_dialog_cheatsheet(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_dialog_delete(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_copy(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_dialog_paste(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_btn_keyboard(assigns), to: RetroHexChatWeb.Icons.Files

  # ── Hardware ────────────────────────────────────────────
  defdelegate icon_laptop(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_browser(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_operating_system(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_server(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_database(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_elixir(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_postgres(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_tab_display(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_dialog_channel_list(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_dialog_channel_central(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_btn_bell(assigns), to: RetroHexChatWeb.Icons.Hardware

  # ── Code ────────────────────────────────────────────────
  defdelegate icon_terminal(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_git(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_code(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_alias(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_auto_respond(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_perform(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_tab_commands(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_btn_perform(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_btn_bot_management(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_bot_management(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_admin_console(assigns), to: RetroHexChatWeb.Icons.Code

  # ── Security ────────────────────────────────────────────
  defdelegate icon_lock(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_shield(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_security(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_ban(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_globe_blocked(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_rules(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_dialog_ignore(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_tab_modes(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_tab_bans(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_tab_exceptions(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_tab_registration(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_privacy(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_dialog_ignore_list(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_btn_ignore_list(assigns), to: RetroHexChatWeb.Icons.Security
  defdelegate icon_btn_flood_protection(assigns), to: RetroHexChatWeb.Icons.Security

  # ── Arrows ──────────────────────────────────────────────
  defdelegate icon_btn_prev(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_next(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_up(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_down(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_refresh(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_export(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_reset(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_join(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_btn_send(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_retry(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_chevron_down(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_chevron_right(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_chevron_left(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_pad_up(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_pad_down(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_pad_left(assigns), to: RetroHexChatWeb.Icons.Arrows
  defdelegate icon_pad_right(assigns), to: RetroHexChatWeb.Icons.Arrows

  # ── Marks ───────────────────────────────────────────────
  defdelegate icon_list_start(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_list_more(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_btn_add(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_btn_remove(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_btn_ok(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_btn_cancel(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_btn_mark_read(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_accept(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_reject(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_close(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_cancel(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_checkmark(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_warning(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_ellipsis(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_radio_dot(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_check_thin(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_close_pixel(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_close_thin(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_minimize(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_maximize(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_restore(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_fullscreen_enter(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_fullscreen_exit(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_help(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_cascade(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_tile_h(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_tile_v(assigns), to: RetroHexChatWeb.Icons.Marks
  defdelegate icon_win_minimize_all(assigns), to: RetroHexChatWeb.Icons.Marks

  # ── Tools ───────────────────────────────────────────────
  defdelegate icon_wrench(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_palette(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_dialog_nick_colors(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_nick_colors(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_edit(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_save(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_apply(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_search(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_set_topic(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_dialog_options(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_dialog_custom_menus(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_tab_control(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_tab_colors(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_group_view(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_group_tools(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_find(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_settings(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_address_book(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_alias_editor(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_custom_menus(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_timers(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_btn_highlight_words(assigns), to: RetroHexChatWeb.Icons.Tools

  # ── Alerts ──────────────────────────────────────────────
  defdelegate icon_document_alert(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_question(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_dialog_about(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_dialog_notifications(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_dialog_highlight(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_dialog_flood(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_tab_general(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_tab_notify(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_tab_notifications(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_tab_status(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_group_notifications(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_group_help(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_lightbulb(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_btn_dnd(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_dialog_away(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_btn_away(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_btn_dnd_active(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_btn_help_topics(assigns), to: RetroHexChatWeb.Icons.Alerts

  # ── Symbols ─────────────────────────────────────────────
  defdelegate icon_dollar(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_star(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_bug(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_heart(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_thumbs_up(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_clap(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_laugh(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_sparkle(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_pin(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_legal(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_clock(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_btn_ignore(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_status_signal(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_dialog_kick(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_dice(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_joystick(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_rss(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_tag(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_hex_stone(assigns), to: RetroHexChatWeb.Icons.Symbols

  # ── Formatting ─────────────────────────────────────────
  defdelegate icon_fmt_toolbar(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_bold(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_italic(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_underline(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_color(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_reverse(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_reset(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_strip(assigns), to: RetroHexChatWeb.Icons.Formatting
  defdelegate icon_fmt_emoji(assigns), to: RetroHexChatWeb.Icons.Formatting

  # ── Games ──────────────────────────────────────────────
  defdelegate game_icon(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_pong(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_trails(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_tanks(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_space(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_gravity(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_debris(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_breakout(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_warlords(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_raid(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_boxing(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_outlaw(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_invaders(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_enduro(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_tennis(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_skiing(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_frost(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_hockey(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_doom(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_freedoom1(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_freedoom2(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_freedm(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_chex(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_hacx(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_rekkr(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_quake(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_quake2(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_librequake(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_wolfenstein(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_halflife(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_bass(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_drascula(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_dreamweb(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_fotaq(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_lure(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_soltys(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_arcade(assigns), to: RetroHexChatWeb.Icons.Games
  defdelegate icon_game_generic(assigns), to: RetroHexChatWeb.Icons.Games

  # ── Flags ──────────────────────────────────────────────
  defdelegate flag_icon(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_en(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_pt_br(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_pt_pt(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_es(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_fr(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_de(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_ja(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_zh_hans(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_zh_hant(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_id(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_ru(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_it(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_pl(assigns), to: RetroHexChatWeb.Icons.Flags
  defdelegate icon_flag_nl(assigns), to: RetroHexChatWeb.Icons.Flags

  # ── New button icons (showcase design system) ──
  defdelegate icon_btn_open(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_btn_page(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_btn_trash(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_btn_star(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_sword(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_btn_play(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_btn_info(assigns), to: RetroHexChatWeb.Icons.Alerts
  defdelegate icon_btn_link(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_btn_menu(assigns), to: RetroHexChatWeb.Icons.Tools
end

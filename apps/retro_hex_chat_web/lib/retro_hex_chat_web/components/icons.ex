defmodule RetroHexChatWeb.Icons do
  @moduledoc """
  Pixel-art SVG icon library for RetroHexChat's Windows 98 interface.

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
  | `Icons.Files`    | Documents, folders, clipboard                 |
  | `Icons.Hardware` | Servers, databases, platforms                 |
  | `Icons.Code`     | Terminal, scripting, automation               |
  | `Icons.Security` | Locks, shields, bans, privacy                 |
  | `Icons.Arrows`   | Directional arrows, navigation                |
  | `Icons.Marks`    | Checkmarks, X marks, status indicators        |
  | `Icons.Tools`    | Settings, editing, search, colors             |
  | `Icons.Alerts`   | Notifications, info, warnings                 |
  | `Icons.Symbols`  | Currency, stars, misc abstract symbols        |

  ## Icon Sizes

  - **32×32** — desktop-style icons (folder, lock, notepad, trash)
  - **16×16** — toolbar, tab, button, and dialog title bar icons

  ## SVG Template

      <svg class={@class} viewBox="0 0 16 16" aria-hidden="true">
        <!-- paths, rects, circles, etc. -->
      </svg>

  Every icon function accepts a single `assigns` map with an optional
  `:class` attribute (default `nil`). All SVGs use `aria-hidden="true"`.

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
  | Gold      | `#FFD700` | Alerts, accents, folder fills  |
  | Red       | `#FF0000` | Danger, errors, close actions  |
  | Green     | `#008000` | Success, active, confirm       |

  ## Contrast Rules

  - **Gray background** (toolbar, tabs, buttons): use navy (`#000080`),
    dark colors, and the full palette above.
  - **Dark background** (dialog title bars): use `#fff` as primary,
    `#FFD700` gold as accent, `#FF0000` red for danger, `#008000` green
    for success. Avoid dark fills that disappear against the gradient.

  ## Stroke / Fill Guidelines

  - Prefer `stroke-width` of `0.5`–`1.5` for 16×16 icons.
  - Use `fill="none"` + stroke for outlined icons.
  - Round caps (`stroke-linecap="round"`) for friendlier appearance.

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
  defdelegate icon_tab_nicklist(assigns), to: RetroHexChatWeb.Icons.People

  # ── Communication ───────────────────────────────────────
  defdelegate icon_p2p(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_chat(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_channels(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_websocket(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_webrtc(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_megaphone(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_send(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_link(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_dialog_invite(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_dialog_url(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_tab_autojoin(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_tab_channel(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_tab_pm(assigns), to: RetroHexChatWeb.Icons.Communication
  defdelegate icon_tab_conversations(assigns), to: RetroHexChatWeb.Icons.Communication

  # ── Media ───────────────────────────────────────────────
  defdelegate icon_microphone(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_camera(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_camera_off(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_mute(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_phone_end(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_pip(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_upgrade_video(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_devices(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_quality_high(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_quality_medium(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_quality_low(assigns), to: RetroHexChatWeb.Icons.Media
  defdelegate icon_dialog_sound(assigns), to: RetroHexChatWeb.Icons.Media

  # ── Files ───────────────────────────────────────────────
  defdelegate icon_folder(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_notepad(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_trash(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_backup(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_file_send(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_choose_file(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_dialog_cheatsheet(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_dialog_delete(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_dialog_log(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_copy(assigns), to: RetroHexChatWeb.Icons.Files
  defdelegate icon_dialog_paste(assigns), to: RetroHexChatWeb.Icons.Files

  # ── Hardware ────────────────────────────────────────────
  defdelegate icon_laptop(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_server(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_database(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_elixir(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_postgres(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_tab_display(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_dialog_channel_list(assigns), to: RetroHexChatWeb.Icons.Hardware
  defdelegate icon_dialog_channel_central(assigns), to: RetroHexChatWeb.Icons.Hardware

  # ── Code ────────────────────────────────────────────────
  defdelegate icon_terminal(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_git(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_code(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_alias(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_ctcp(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_auto_respond(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_dialog_perform(assigns), to: RetroHexChatWeb.Icons.Code
  defdelegate icon_tab_commands(assigns), to: RetroHexChatWeb.Icons.Code

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
  defdelegate icon_privacy(assigns), to: RetroHexChatWeb.Icons.Security

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

  # ── Marks ───────────────────────────────────────────────
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

  # ── Tools ───────────────────────────────────────────────
  defdelegate icon_wrench(assigns), to: RetroHexChatWeb.Icons.Tools
  defdelegate icon_palette(assigns), to: RetroHexChatWeb.Icons.Tools
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

  # ── Symbols ─────────────────────────────────────────────
  defdelegate icon_dollar(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_star(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_bug(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_heart(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_legal(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_clock(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_btn_ignore(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_status_signal(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_dialog_kick(assigns), to: RetroHexChatWeb.Icons.Symbols
  defdelegate icon_tag(assigns), to: RetroHexChatWeb.Icons.Symbols
end

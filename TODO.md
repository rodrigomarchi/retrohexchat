# TODO

Things found that need fixing or checking later. Each item says where it was found,
what the docs claim and what the code does. Delete an item when it is fixed.

## Broken in production

- [ ] **Every GitHub link points at a repository that does not exist.** The app links to
      `github.com/rodrigomarchi/retro_hex_chat` (404, no redirect) — the repository is
      `github.com/rodrigomarchi/retrohexchat`. 75 occurrences: Start ▸ Help ▸ GitHub and
      License (MIT) (`start_menu_app.ex`), the landing (`landing_shell.ex`, `landing_mockups.ex`,
      `community.html.heex`), desktop launchers, `seo.ex` (structured data), `priv/static/llms.txt`,
      `CONTRIBUTING.md`, docs. Found 2026-10-08 checking EP01's description links. SEO-visible:
      follow the public-page snapshot/diff rule when fixing.

## Docs that contradict the code

Found 2026-10-08, while scripting the YouTube channel's first episode.

- [ ] **README advertises a command palette on `Ctrl+/` that does not exist.**
      `README.md` (UI & Keyboard) — "Command palette — `Ctrl+/` to browse every slash command".
      `Ctrl+/` is unbound. What exists is the command autocomplete that opens when you type `/`
      (grouped by category, fuzzy search).
- [ ] **The cheatsheet help topic gives the wrong shortcut.**
      `apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics/features.ex` — "Quick reference
      overlay showing all keyboard shortcuts, opened with Ctrl+/."
      `RetroHexChat.Chat.KeyBindings` binds `toggle_cheatsheet` to **Ctrl+Shift+/**.
      A msgid change: goes through the i18n pipeline (`.claude/rules/i18n.md`).
- [ ] **The showcase cheatsheet dialog shows the wrong keys.**
      `apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/showcase_live/dialogs/cheatsheet_dialog_page.ex`
      — `keys: "Ctrl+/"`; should be `Ctrl+Shift+/`.
- [ ] **"No sign-up" is not quite true.**
      `README.md` — "no install, no sign-up, pick a nick and join".
      A new nickname is registered with a password on connect (no email). Decide the wording:
      "no email, no install" is accurate.
- [ ] **The help topic for autocomplete calls it a "command palette".**
      `apps/retro_hex_chat_web/lib/retro_hex_chat_web/controllers/help_content/feature_autocomplete.html.heex`
      — "Type / to open the command palette". Check it reads consistently with the README fix
      above (one name for one thing).

## UI defects

- [ ] **ChanServ shows a raw timestamp.** Channel Central → Registration, "Since:" reads
      `2026-10-08 16:19:14.379859Z` — ISO with microseconds and a `Z`, where every other date in
      the UI is formatted. Found 2026-10-08 filming EP01 scene 3.

## Test helpers

- [ ] **`enterThroughNewCard` can follow a stale card.**
      `e2e/helpers/surfaceEntry.ts` — its poll falls back to `addresses.at(-1)` on the very first
      try, so when the new card has not rendered yet it returns the conversation's previous bottom
      card. Found 2026-10-08 filming EP01: a Space press in a channel full of conference cards
      opened the conference. Fix: wait for an address not seen before the press, and fall back to
      the bottom card only when none appears (as `e2e/director/space.ts` →
      `enterThroughFreshCard` does).

## To verify

- [ ] **README "Virtual Spaces — switch any channel or DM from Chat to Space".**
      Space opens from a card into its own tab, with a character select; there is no in-place
      switch. Check the README and help topics describe the card.

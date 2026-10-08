# TODO

Things found that need fixing or checking later. Each item says where it was found,
what the docs claim and what the code does. Delete an item when it is fixed.

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

## To verify

- [ ] **README "Virtual Spaces — switch any channel or DM from Chat to Space".**
      Space opens from a card into its own tab, with a character select; there is no in-place
      switch. Check the README and help topics describe the card.

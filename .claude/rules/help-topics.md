---
paths:
  - "apps/retro_hex_chat/lib/retro_hex_chat/commands/**"
  - "apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex"
  - "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/**"
  - "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/**"
---

# Help documentation is mandatory (Principle XI)

Every user-facing change adds or updates topics in `RetroHexChat.Chat.HelpTopics`
(`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`):

- New command → a topic in the **Commands** category (syntax, examples, "See Also")
- New feature → a topic in the **Features** category
- New UI element (window, dialog, toolbar) → a topic in the **User Interface** category
- New keyboard shortcut → update the **Keyboard Shortcuts** topic
- Update "See Also" cross-references in related topics
- Reuse existing topic IDs when a new one already maps to an existing topic
  (`cmd-invite` vs `invite_send`) — update in place, never duplicate

Accessible via F1, Help menu → Help Topics, and `/help`. Stale or inaccurate help
is a defect. Full rule: [`docs/AGENT-GUIDE.md` §12](../../docs/AGENT-GUIDE.md).

Each `/` command is a separate Handler module.

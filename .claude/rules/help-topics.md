---
paths:
  - "apps/retro_hex_chat/lib/retro_hex_chat/commands/**"
  - "apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex"
  - "apps/retro_hex_chat_web/lib/retro_hex_chat_web/live/**"
  - "apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/**"
---

# Help documentation is mandatory (Principle XI)

Every change that gives the reader something to **do** adds or updates topics in
`RetroHexChat.Chat.HelpTopics`
(`apps/retro_hex_chat/lib/retro_hex_chat/chat/help_topics.ex`):

- New command → a topic in the **Commands** category (syntax, examples, "See Also")
- New feature → a topic in the **Features** category
- New UI element (window, dialog, toolbar) → a topic in the **User Interface** category
- New keyboard shortcut → update the **Keyboard Shortcuts** topic
- Update "See Also" cross-references in related topics
- Reuse existing topic IDs when a new one already maps to an existing topic
  (`cmd-invite` vs `invite_send`) — update in place, never duplicate

**No control surface, no topic.** The test is not "can the reader see it" but "is
there anything the reader could type, click or choose here". Styling, a colour, a
wallpaper, spacing, an animation — things they cannot act on and could not change if
they wanted to — get nothing. Help answers "how do I…", never "what am I looking
at", and a topic that only says a thing exists makes the help longer without making
it more useful.

Accessible via the Help menu → Help Topics and `/help`. Nothing binds F1 — it is
in `@reserved_fkeys` because the browser owns it. Stale or inaccurate help
is a defect. Full rule: [`docs/AGENT-GUIDE.md` §12](../../docs/AGENT-GUIDE.md).

Each `/` command is a separate Handler module.

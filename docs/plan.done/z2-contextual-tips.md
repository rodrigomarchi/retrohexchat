# Category Z2: Contextual Tips & Progressive Disclosure

**Priority**: Yellow (High — teaches features at the right moment)
**Dependencies**: Z (Onboarding) for first-run detection; various features must exist to give tips about them
**Existing**: None (new category)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| Z10 | Contextual tip: first message sent | New | After sending first message: "Use ↑ para editar sua última mensagem" |
| Z11 | Contextual tip: first /join | New | After first channel join: "Canais aparecem no painel esquerdo" |
| Z12 | Contextual tip: first PM received | New | On first PM: "PMs aparecem como janelas separadas no treebar" |
| Z13 | Contextual tip: first highlight | New | On first mention: "Seu nick foi mencionado! Configure alertas em Settings" |
| Z14 | Contextual tip: idle user | New | After 30s idle: "Digite /help para ver todos os comandos" |
| Z15 | Tip toast component | New | Reusable 98.css toast: message text, "Entendi!" button, "Não mostrar mais" checkbox. Used also by AB and AC. |
| Z16 | Tip seen tracking | New | Each tip shown at most once via localStorage keys, global toggle in Settings |

## Dependencies Detail

- Z10-Z14 each depend on detecting a specific user event for the first time
- Z15 (toast component) is the reusable UI infrastructure — also used by AB5/AB6 (copy/settings toasts) and AC4 (notification toasts)
- Z16 (tracking) provides the localStorage mechanism for "seen" flags and global "tips_disabled" toggle
- Z (Onboarding) handles first-run wizard; this category handles ongoing progressive disclosure after onboarding

## Technical Notes

- Each tip has a unique localStorage key (e.g., "tip_first_message_seen", "tip_first_join_seen")
- Toast component: positioned fixed bottom-right, z-index above chat but below dialogs and modals
- Toast auto-dismiss after 8 seconds, or manual dismiss via "Entendi!" button
- "Não mostrar mais" checkbox sets a global "tips_disabled" flag in localStorage
- Tips fire via handle_info in ChatLive — each event checks if the tip was already seen
- If multiple tips would trigger simultaneously, queue them and show one at a time with a 2-second gap
- This toast component is the canonical implementation — AB and AC categories should reuse it, not create their own

---

## Spec Command

```
/speckit.specify "Contextual Tips & Progressive Disclosure for RetroHexChat.

PROBLEM: After the initial onboarding wizard (Category Z), users have no way to discover features as they naturally encounter them. There are dozens of commands, keyboard shortcuts, and UI interactions that users will only learn if they stumble upon them or read documentation. Contextual tips solve this by showing the right hint at the right moment — teaching features when the user first encounters the relevant context.

EXISTING CONTEXT: No contextual tip system exists. The onboarding wizard (Category Z) handles first-run guidance. Various features that tips would reference are already implemented: command palette, nick autocomplete, history navigation, highlight system, etc.

USER JOURNEY: A user sends their first message in a channel. A small 98.css toast appears in the bottom-right corner: 'Use ↑ para editar sua última mensagem'. The toast has an 'Entendi!' dismiss button and a small 'Não mostrar mais dicas' checkbox. It auto-dismisses after 8 seconds if the user does not interact with it.

Later, when they join their first channel via /join, another tip appears: 'Canais que você entra aparecem no painel esquerdo'. When they receive their first PM: 'PMs aparecem como janelas separadas no treebar'. When someone mentions their nick for the first time: 'Seu nick foi mencionado! Configure alertas em Settings'. If they are idle for 30 seconds: 'Digite /help para ver todos os comandos'.

Each tip appears at most once — ever. If the user checks 'Não mostrar mais dicas', all future tips are globally suppressed. Tips can be re-enabled in Settings. The toast component created here is reusable — other categories (AB Visual Feedback, AC Notifications) use the same component for their own toast messages.

ACTORS: Contextual tips target all users (not just first-time). Each tip fires only once per user. Tip state is persisted in localStorage (works for both guests and registered users).

EDGE CASES: If multiple tips would trigger at the same moment (e.g., first message + first join happen simultaneously), they should queue and show one at a time with a 2-second gap between them. Tips must not appear while a dialog or modal is open — they should queue until the dialog closes. If the user has already demonstrated knowledge of a feature (e.g., they used /help before the idle tip fires), the tip should be marked as seen and not shown. If localStorage is full, gracefully skip tip tracking rather than throwing errors.

NEGATIVE REQUIREMENTS: Tips must NOT appear more than once per type — ever. Tips must NOT block or overlay important UI elements (positioned in bottom-right corner). Tips must NOT interrupt the user's typing — never steal focus from the input. The 'Não mostrar mais' toggle must NOT reset when localStorage is cleared for other reasons (it should be the most resilient setting). Tips must NOT appear during the onboarding wizard flow.

SCOPE: In scope — 5 contextual tip triggers (first message, first join, first PM, first highlight, idle), reusable toast component (98.css styled with dismiss button and global toggle checkbox), per-tip seen tracking in localStorage, global tips toggle in Settings. Out of scope — tip content customization, more than 5 initial tips (can be extended later), tip analytics, tips in languages other than Portuguese."
```

# Category Z: Onboarding & Empty States

**Priority**: Yellow (High — guides new users)
**Dependencies**: Multiple features should exist before onboarding references them
**Existing**: None (new category)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| Z1 | Welcome wizard - nickname step | New | First-run retro wizard dialog: welcome message, nickname input with tip |
| Z2 | Welcome wizard - server step | New | Server address/port pre-filled, SSL checkbox, "leave default" guidance |
| Z3 | Welcome wizard - channel step | New | List of popular channels with user counts, checkboxes to join, manual input |
| Z4 | First-run detection | New | Detect first visit via localStorage flag, trigger wizard only once |
| Z5 | Post-wizard banner | New | After wizard, subtle banner in chat: "/ para comandos, ↑↓ para histórico" |
| Z6 | Empty state: new channel | New | Channel with no messages shows welcome message with tips |
| Z7 | Empty state: empty nicklist | New | Nicklist with no users shows "Ninguém aqui — Você é o(a) primeiro(a)!" |
| Z8 | Empty state: no channels | New | Treebar with no channels shows "/join #canal" guidance + "Explorar canais" button |
| Z9 | Empty state: empty URL list | New | URL catcher with no URLs shows guidance text |

## Dependencies Detail

- Z1-Z5 (onboarding wizard) is self-contained but benefits from existing features to reference in tips
- Z6-Z9 (empty states) are independent — each replaces blank content in specific views
- Z9 depends on E (URL Catcher) existing
- Contextual tips (progressive disclosure) are handled by Category Z2 (Contextual Tips), not here

## Technical Notes

- Welcome wizard: retro wizard pattern (multi-step dialog with Back/Next/Finish buttons)
- First-run detection: check localStorage key "retro_hex_chat_onboarded" — if absent, show wizard
- Empty states: rendered as centered content within the normally-empty container
- Empty states should use friendly language and actionable guidance (not just "nothing here")
- Empty states must disappear immediately when content arrives (e.g., first message replaces the empty state)
- All guidance text should be in Portuguese (Brazilian) matching the app's personality

---

## Spec Command

```
/speckit.specify "Onboarding & Empty States for RetroHexChat.

PROBLEM: New users face a blank, intimidating interface with no guidance. Classic IRC had a brutal learning curve — dozens of slash commands, obscure shortcuts, no visual hints. RetroHexChat looks like retro but should feel welcoming. Currently, a first-time user sees an empty chat, does not know what to type, does not know that commands start with /, and may not even know how to join a channel. Empty screens throughout the app (empty channel, empty nicklist, empty treebar, empty URL list) provide no guidance — just blank space.

EXISTING CONTEXT: No onboarding or empty state features are currently implemented. The app launches directly into the chat view. The connect flow (ConnectLive) exists but has no first-run wizard.

USER JOURNEY — ONBOARDING WIZARD: A first-time user opens RetroHexChat. A retro-style wizard dialog appears. Step 1: Welcome message with ASCII/pixel art logo, nickname input field with a tip explaining what a nick is ('Seu nick é como seu nome no chat. Pode mudar depois com /nick'). Step 2: Server configuration with sensible defaults pre-filled — the tip says 'Não sabe o que escolher? Deixe o padrão!'. SSL checkbox. Step 3: After connecting, a list of popular channels with user counts appears as checkboxes, plus a text field to type a custom channel name. A 'Pular' (skip) button lets the user skip this step. The user selects #general and clicks 'Entrar!'. The wizard closes, they join the selected channels, and a subtle banner appears in the chat: 'Dica: digite / para ver comandos disponíveis. Use ↑↓ para navegar o histórico.'

The wizard only appears once. On subsequent visits, the user goes directly to the chat.

USER JOURNEY — EMPTY STATES: The user joins a brand new channel with no messages. Instead of a blank screen, they see a centered welcome: 'Bem-vindo ao #general! Este é o início do canal. Diga oi! Dica: /topic para ver o tópico'. An empty nicklist shows: 'Ninguém aqui — Você é o(a) primeiro(a)!'. A treebar with no channels shows: 'Nenhum canal — /join #canal para começar' with an 'Explorar canais' button that opens the channel list. The URL catcher with no URLs shows: 'Nenhuma URL capturada. URLs mencionadas no chat aparecerão aqui.'

ACTORS: Onboarding targets new users (first visit). Empty states are visible to everyone when the relevant container is empty. Guest users should also see onboarding.

EDGE CASES: If the user closes the wizard mid-flow (X button or Esc), mark onboarding as complete to avoid re-triggering — assume they know what they are doing. If localStorage is cleared, the wizard will re-appear — this is acceptable. Empty states must disappear immediately when content arrives (e.g., first message in a channel replaces the empty state instantly). The wizard must handle connection failures gracefully — if the server connection fails in step 2, show an error and let the user retry without restarting the wizard. The 'Explorar canais' button in the treebar empty state must work even if the channel list feature is not fully loaded yet.

NEGATIVE REQUIREMENTS: The wizard must NOT force the user to join channels — step 3 must have a 'Pular' (skip) option. Empty states must NOT persist after content loads — they must vanish instantly. The wizard must NOT appear on subsequent visits even if the user did not complete all steps. Empty state text must NOT be selectable/copyable as if it were a chat message.

SCOPE: In scope — 3-step welcome wizard (nickname, server, channels), first-run detection via localStorage, post-wizard banner, 4 empty states (channel, nicklist, treebar, URL list). Out of scope — contextual tips and progressive disclosure (that is Category Z2), interactive tutorial/walkthrough overlay, video guides, onboarding analytics."
```

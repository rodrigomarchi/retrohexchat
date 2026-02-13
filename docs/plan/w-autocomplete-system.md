# Category W: Autocomplete System

**Priority**: Red (Critical — foundational for intelligent interaction)
**Dependencies**: None (foundational)
**Existing**: W1 command palette already implemented (command_palette.ex + command_palette_hook.js)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| W1 | Command palette dropdown | Existing | Slash-command autocomplete palette displayed above input, 98.css-styled |
| W2 | Fuzzy match for commands | New | Fuzzy search so "/jo" matches "/join", not just prefix match |
| W3 | Command categories in dropdown | New | Group commands by category (Básicos, Canal, Usuário, Configuração, Avançado) |
| W4 | Recent commands priority | New | Last 5 used commands appear first in a "Recentes" section |
| W5 | Context-aware argument completion | New | After "/msg " suggest nicks, after "/join " suggest channels, after "/kick " suggest channel nicks |
| W6 | Nick autocomplete (@mention) | New | Typing @ or first letters + Tab suggests nicknames with fuzzy match and ↑↓/Tab/Esc navigation |
| W7 | Channel autocomplete (#) | New | Typing # suggests channels with user count, joined channels marked with ✓ |

## Dependencies Detail

- W1 (existing) provides the base dropdown UI and hook infrastructure for all autocomplete features
- W5 (argument completion) depends on Channels context for channel list and Presence for nick list
- W6 (nick autocomplete) depends on Presence for visible users, uses same dropdown UI as W1
- W7 (channel autocomplete) depends on Channels context for available channels
- W6 and W7 feed into Y2 (Interactive Elements) for clickable nicks/channels in chat
- W2-W5 extend the existing command_palette.ex and command_palette_hook.js
- After a command is selected via autocomplete, the syntax tooltip experience belongs to Category X (Smart Input)

## Technical Notes

- Existing command_palette.ex renders a 98.css-styled window above input with filtered command list
- Existing command_palette_hook.js handles / trigger, ↑↓ navigation, Tab/Enter confirm, Esc dismiss
- Fuzzy match should use substring matching (not just prefix) — "jo" matches "/join" and "/autojoin"
- Nick autocomplete classic IRC behavior: at start of line `Mar<Tab>` → `Mario: ` (with colon), mid-line `Mar<Tab>` → `Mario ` (without colon)
- Tab-Tab cycles through multiple matches (IRC convention)
- Channel autocomplete dropdown should show channel name + user count, with joined channels sorted first
- All three autocomplete types share the same 98.css dropdown pattern and ↑↓/Tab/Esc keyboard navigation

---

## Spec Command

```
/speckit.specify "Autocomplete System for RetroHexChat.

PROBLEM: Users must currently type commands, nicknames, and channel names from memory with no assistance. The existing command palette provides basic slash-command listing but lacks fuzzy search, categorization, recent command tracking, and context-aware argument completion. There is no autocomplete for nicknames or channel names at all. In classic mIRC, Tab-completion for nicks was essential — without it, busy channels with many users become frustrating. Modern chat applications go further with rich autocomplete dropdowns.

EXISTING CONTEXT: A command palette (command_palette.ex + command_palette_hook.js) is already implemented. It shows a 98.css-styled dropdown above the input when the user types '/', lists available commands with descriptions, supports ↑↓ keyboard navigation, Tab/Enter to confirm, and Esc to dismiss. This provides the foundational UI pattern and hook infrastructure for all autocomplete features.

USER JOURNEY — COMMAND AUTOCOMPLETE: A user types '/' in the input. The existing command palette appears showing all commands. As they type '/jo', the list filters using fuzzy match to show '/join' and '/autojoin'. Commands are organized by category (Básicos, Canal, Usuário, Configuração, Avançado). Their 5 most recently used commands appear in a 'Recentes' section at the top. They select '/join' with Tab — the input fills with '/join ' and the autocomplete dropdown closes. As they continue typing '/join #', a new sub-dropdown appears listing available channels with user counts, allowing them to select a channel argument.

USER JOURNEY — NICK AUTOCOMPLETE: A user in a busy channel wants to mention someone. They type '@ma' — a dropdown appears showing matching nicknames: @Mario (Online), @Marcelo (Away), @MasterDev (Online). Each nick shows their chat color and status icon. They press Tab to confirm '@Mario'. Alternatively, at the start of a message they type 'Mar' and press Tab — it completes to 'Mario: ' with a colon (IRC convention). In the middle of a sentence, Tab completes to 'Mario ' without the colon. Pressing Tab again cycles to the next match.

USER JOURNEY — CHANNEL AUTOCOMPLETE: A user types '#de' anywhere in their message. A dropdown shows matching channels: #dev (5 users, ✓ joined), #design (3 users), #debian (12 users). Channels the user has already joined appear first with a checkmark. Selecting a channel inserts the full name.

ACTORS: Any connected user (guest or registered) can use all autocomplete features. The recent commands list is per-user and persisted in localStorage.

EDGE CASES: Empty channel list or no matching nicks should show a 'No results' message in the dropdown. Autocomplete should work in the Status window (commands only, no nick/channel). If the user deletes back past the trigger character (@, #, /), the dropdown should close. Very long command lists should be scrollable with a max visible height. Nick autocomplete must handle nick changes in real-time — if a user changes nick while the dropdown is open, the list should update. Multiple autocomplete triggers in one message should work independently (e.g., '/msg @nick check #channel'). Autocomplete dropdown must not extend beyond the viewport — reposition if needed.

NEGATIVE REQUIREMENTS: Autocomplete must NOT send any messages — it only assists with input composition. The dropdown must NOT steal focus from the input field. Nick autocomplete must NOT show the user's own nick as the first suggestion. Channel autocomplete must NOT show secret/hidden channels (+s) the user is not a member of.

SCOPE: In scope — fuzzy command search, command categories, recent commands, context-aware argument completion (nicks after /msg, channels after /join, channel nicks after /kick), nick autocomplete with @ trigger and Tab-completion, channel autocomplete with # trigger, shared 98.css dropdown UI. Out of scope — inline syntax hints after command selection (that belongs to Category X Smart Input), emoji autocomplete, custom autocomplete providers, autocomplete in dialogs (only in chat input)."
```

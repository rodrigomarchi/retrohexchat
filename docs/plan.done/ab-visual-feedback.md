# Category AB: Visual Feedback & Unread Indicators

**Priority**: Red (Critical — every action needs clear visual response)
**Dependencies**: Z2 (Contextual Tips) for toast component reuse
**Existing**: None (new category)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AB1 | Optimistic message send | New | Sent messages appear instantly in chat before server confirmation |
| AB2 | Message send failure indicator | New | ⚠️ icon on failed messages with "Click to resend" tooltip |
| AB3 | Channel join/part flash | New | Green flash on treebar item when joining, visual feedback on part |
| AB4 | Kick notification dialog | New | 98.css dialog: "Você foi expulso de #canal por User: motivo" |
| AB5 | Copy confirmation toast | New | Brief "Copiado!" toast when text is copied (reuses Z15 toast component) |
| AB6 | Settings saved toast | New | "Configurações salvas" toast after settings changes (reuses Z15 toast component) |
| AB7 | Unread indicators in treebar | New | Bold text for unread, numeric badge for count, red dot for highlights/mentions |
| AB8 | Treebar visual states | New | Normal, unread (bold), highlight (bold+red badge), active (selected bg), muted (gray), disconnected (⚡+gray) |

## Dependencies Detail

- AB1-AB2 (optimistic send) requires changes to message sending flow in ChatLive
- AB5-AB6 reuse the toast component created by Z15 (Contextual Tips)
- AB7-AB8 (unread indicators) depend on tracking read/unread state per channel in LiveView assigns
- AB7 provides the visual rendering for unread badges — AC3 (Notification routing) decides WHEN to update them
- AB3 (join/part flash) uses CSS animations on treebar items

## Technical Notes

- Optimistic UI: insert message into stream immediately, mark with pending state, update on server confirm
- Failed messages: add error class + retry click handler, distinct visual treatment (red border, ⚠️ icon)
- Unread tracking: maintain per-channel last-read timestamp in assigns, compare with message timestamps
- Treebar states: use CSS classes for bold/red-dot/gray/selected — no stream manipulation needed
- Toast reuse: import Z15's toast component, call with message text and auto-dismiss duration
- Kick dialog: standard 98.css dialog with channel name, kicker nick, reason, and OK button

---

## Spec Command

```
/speckit.specify "Visual Feedback & Unread Indicators for RetroHexChat.

PROBLEM: Many user actions lack clear visual feedback. Sending a message provides no confirmation if it succeeds or fails. Joining or leaving a channel has no visual emphasis in the treebar. Being kicked from a channel shows no clear notification. There are no unread indicators in the treebar — users cannot tell which channels have new messages, which have mentions, or which are muted. Copy and settings operations provide no confirmation. Without comprehensive visual feedback, users feel uncertain about whether their actions worked.

EXISTING CONTEXT: No visual feedback system or unread indicator system currently exists. The treebar shows channels in a flat list with no visual state differentiation. Messages are sent synchronously with no optimistic UI. A toast component will be available from Category Z2 (Contextual Tips) for copy/settings confirmations.

USER JOURNEY — ACTION FEEDBACK: A user sends a message. It appears instantly in the chat with a subtle pending indicator (optimistic UI). Once the server confirms, the indicator disappears. If the send fails (e.g., network issue), a ⚠️ icon appears next to the message with a tooltip: 'Falha ao enviar. Clique para reenviar'. They click the icon and the message is retried.

The user joins a new channel — the treebar item flashes green briefly. They are kicked from a channel — a 98.css dialog appears: 'Você foi expulso de #canal por AdminNick: motivo' with an OK button. They copy text from the chat — a brief 'Copiado!' toast appears at the bottom-right and fades after 2 seconds. They save settings — a 'Configurações salvas' toast confirms.

USER JOURNEY — UNREAD INDICATORS: In the treebar, channels with unread messages show bold text. Channels with a specific count show a numeric badge (e.g., '3'). Channels where the user was mentioned show a red dot badge. The currently active channel has a selected background. Muted channels appear grayed out with no badges. A disconnected channel shows a ⚡ icon with gray text. When the user switches to a channel, its unread state resets. If the unread count exceeds 99, it shows '99+'.

ACTORS: All visual feedback is visible to any connected user. Unread indicators and muted states are per-user.

EDGE CASES: If multiple messages fail to send, each should have its own retry button. If the user is in multiple channels and switches rapidly, unread counts must update accurately without race conditions. Optimistic messages that fail should remain visually distinct (not blend with successful messages) even after scrolling. The kick dialog must handle the case where the user was kicked from multiple channels simultaneously (queue dialogs). Unread badges should not count system messages (joins, parts, quits) — only user messages and highlights.

NEGATIVE REQUIREMENTS: Optimistic UI must NOT show the message as fully 'sent' until server confirms — use a subtle pending visual state (e.g., slightly faded). Toasts must NOT stack more than 3 at once — queue additional ones. Unread badges must NOT count system messages — only user messages and highlights. The kick dialog must NOT auto-dismiss — it requires user acknowledgment via OK button.

SCOPE: In scope — optimistic message send with pending state and failure/retry, channel join flash and kick dialog, copy and settings toast confirmations (via Z15 component), unread indicators (bold text, numeric badge, red dot) in treebar, 6 treebar visual states (normal, unread, highlight, active, muted, disconnected). Out of scope — status bar enhancements (Category AB2), loading states (Category AB2), desktop/browser notifications (Category AC), sound feedback (Category O)."
```

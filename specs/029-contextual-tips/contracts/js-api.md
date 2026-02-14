# JavaScript API Contracts: Contextual Tips

**Feature**: 029-contextual-tips | **Date**: 2026-02-14

## `lib/tips.js` — Pure Tip State Logic

### Constants

```javascript
export const TIP_IDS = {
  FIRST_MESSAGE: "first_message",
  FIRST_JOIN: "first_join",
  FIRST_PM: "first_pm",
  FIRST_HIGHLIGHT: "first_highlight",
  IDLE_HELP: "idle_help",
};

export const TIPS = [
  { id: "first_message", text: "Use ↑ para editar sua última mensagem" },
  { id: "first_join", text: "Canais que você entra aparecem no painel esquerdo" },
  { id: "first_pm", text: "PMs aparecem como janelas separadas no treebar" },
  { id: "first_highlight", text: "Seu nick foi mencionado! Configure alertas em Settings" },
  { id: "idle_help", text: "Digite /help para ver todos os comandos", preemptedBy: "help_used" },
];

export const STORAGE_KEYS = {
  SEEN: "retro_hex_chat_tips_seen",
  SUPPRESSED: "retro_hex_chat_tips_suppressed",
  SUPPRESSED_BACKUP: "retro_hex_chat_tips_suppressed_backup",
};

export const AUTO_DISMISS_MS = 8000;
export const QUEUE_GAP_MS = 2000;
export const IDLE_TIMEOUT_MS = 30000;
```

### Functions

#### `isSuppressed() → boolean`
Returns `true` if tips are globally suppressed (checks both primary and backup keys).

#### `setSuppressed(value: boolean) → void`
Sets or clears the global suppression flag in both primary and backup keys.

#### `isTipSeen(tipId: string) → boolean`
Returns `true` if the specified tip has already been seen.

#### `markTipSeen(tipId: string) → void`
Marks a tip as seen in localStorage. Gracefully handles storage full errors.

#### `shouldShowTip(tipId: string) → boolean`
Returns `true` if the tip should be shown (not suppressed, not seen, not preempted).

#### `markPreempted(actionId: string) → void`
Marks any tips that are preempted by the given action as seen (e.g., `"help_used"` preempts `"idle_help"`).

#### `getTipById(tipId: string) → TipDefinition | undefined`
Returns the tip definition for the given ID.

#### `resetAllTips() → void`
Clears all seen state (for testing/debugging only).

---

## `lib/toast.js` — Pure Toast DOM Logic

### Functions

#### `createToastElement(tip: TipDefinition, options: ToastOptions) → HTMLElement`
Creates a 98.css-styled toast window element with title bar, tip text, dismiss button, and optional checkbox.

**ToastOptions**:
| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `showCheckbox` | `boolean` | `true` | Whether to show "Não mostrar mais dicas" checkbox |
| `onDismiss` | `function` | required | Called when "Entendi!" is clicked |
| `onSuppress` | `function` | required | Called when checkbox is checked and toast dismissed |

#### `positionToast(element: HTMLElement) → void`
Positions the toast in the bottom-right corner, clearing the status bar.

#### `animateIn(element: HTMLElement) → void`
Applies entry animation (fade-in + slide-up).

#### `animateOut(element: HTMLElement) → Promise<void>`
Applies exit animation (fade-out) and resolves when complete.

---

## `hooks/contextual_tips_hook.js` — Hook Wiring

### Lifecycle

#### `mounted()`
- Initialize tip queue (empty array)
- Attach `handleEvent("tip_trigger", ...)` listener
- Attach `handleEvent("tips_toggle", ...)` listener
- Start idle timer (30s, reset on keydown/mousemove/click)
- Push `tips_state_sync` with current suppression state
- If `show_onboarding_tip` is active (banner visible), delay tip processing by 5 seconds

#### `destroyed()`
- Clear idle timer
- Remove event listeners
- Clear any pending queue timers
- Remove any visible toast element

### Internal State (not persisted)

| Field | Type | Description |
|-------|------|-------------|
| `queue` | `Array` | Pending tips to show |
| `isShowing` | `boolean` | Whether a toast is currently visible |
| `cooldownTimer` | `number \| null` | Timer ID for inter-tip gap |
| `idleTimer` | `number \| null` | Timer ID for idle detection |
| `autoDismissTimer` | `number \| null` | Timer ID for 8s auto-dismiss |

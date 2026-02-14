# Data Model: Visual Feedback & Unread Indicators

All entities are ephemeral — stored in socket assigns or client-side runtime state. No database migrations required.

## Entities

### UnreadState (Server-side, per-socket)

Replaces the existing `unread_channels` MapSet with richer tracking.

| Field | Type | Description |
|-------|------|-------------|
| `unread_counts` | `%{String.t() => non_neg_integer()}` | Map of channel/PM key to unread message count. Replaces `unread_channels` MapSet. |
| `highlight_channels` | `MapSet.t(String.t())` | Channels where the user's nick was mentioned. Existing assign — no change. |
| `muted_channels` | `MapSet.t(String.t())` | Channels the user has muted. Existing assign — no change. |
| `flash_channels` | `MapSet.t(String.t())` | Channels currently flashing. Existing assign — no change. |

**State transitions**:
- `increment(counts, channel)` — Add 1 to channel's count (on new user message in inactive channel).
- `reset(counts, channel)` — Set channel count to 0 and remove from highlight (on channel switch).
- `get_count(counts, channel)` — Return current count for badge display.
- `display_count(count)` — Return string: `""` if 0, `"99+"` if > 99, else `"#{count}"`.

**Invariants**:
- System messages (type `:system`, `:join`, `:part`, `:quit`, `:mode`, `:topic`) MUST NOT increment the count.
- Muted channels still increment internally — suppression is display-only.
- PM keys use `"pm:#{nickname}"` format (consistent with existing `unread_channels`).

### KickQueue (Server-side, per-socket)

| Field | Type | Description |
|-------|------|-------------|
| `kick_queue` | `[KickEvent.t()]` | List of pending kick notifications. First item is displayed. |

**KickEvent struct**:

| Field | Type | Description |
|-------|------|-------------|
| `channel` | `String.t()` | Channel the user was kicked from. |
| `operator` | `String.t()` | Nickname of the operator who kicked. |
| `reason` | `String.t() \| nil` | Optional kick reason. |

**State transitions**:
- `enqueue(queue, event)` — Append kick event to the queue.
- `dequeue(queue)` — Remove the first event (user clicked OK).
- `current(queue)` — Return the first event for display (or nil if empty).

### MessageStatus (Client-side, per-message)

| Field | Type | Description |
|-------|------|-------------|
| `status` | `:pending \| :confirmed \| :failed` | Current lifecycle state. |
| `temp_id` | `String.t()` | Client-generated temporary ID (e.g., `"pending_1707912345678"`). |
| `content` | `String.t()` | Message content for retry. |
| `target` | `String.t()` | Channel or PM target for retry. |
| `error` | `String.t() \| nil` | Error reason if failed. |

**State transitions**:
- `pending` → `confirmed` (server confirms delivery via `message_confirmed` event).
- `pending` → `failed` (server reports error via `message_failed` event).
- `failed` → `pending` (user clicks retry).

### FeedbackToast (Client-side, ephemeral)

| Field | Type | Description |
|-------|------|-------------|
| `message` | `String.t()` | Toast text (e.g., "Copiado!", "Configurações salvas"). |
| `duration` | `non_neg_integer()` | Auto-dismiss duration in ms (default: 2000). |

No queue management needed — reuses the existing Z2 toast queue infrastructure.

## Entity Relationships

```text
Socket Assigns
├── unread_counts: %{channel => count}  ──→  Treebar badge rendering
├── highlight_channels: MapSet          ──→  Treebar red dot rendering
├── muted_channels: MapSet              ──→  Treebar suppresses badges
├── flash_channels: MapSet              ──→  Treebar flash animation
└── kick_queue: [KickEvent]             ──→  Kick dialog rendering

Client Runtime
├── MessageStatus (per pending msg)     ──→  Chat message pending/failed UI
└── FeedbackToast (via Z2 queue)        ──→  Toast display
```

# Research: Session Persistence

## R1: PM Partner Query Strategy

**Decision**: Use a single SQL query with `UNION` + `DISTINCT ON` to extract unique PM partners ordered by most recent message timestamp.

**Rationale**: The existing `private_messages` table has a composite index `idx_pm_conversation` on `(LEAST(sender, recipient), GREATEST(sender, recipient), inserted_at DESC)`. A query using `UNION` of sender/recipient perspectives, grouped by partner nick with `MAX(inserted_at)`, then ordered by recency and limited to 50, will leverage this index efficiently.

**Alternatives considered**:
- Materialized view for PM partners: Over-engineered for this use case. The query runs once per connect, not per request.
- Separate `pm_conversations` table: Would require a new migration and sync logic. The `private_messages` table already has all needed data.
- Client-side localStorage persistence: Would not survive browser/device changes. DB is the source of truth for registered users.

## R2: PM Conversation Auto-Open — Where to Hook

**Decision**: Modify `apply_new_pm/3` in `PubsubHandlers.Messages` to call `Session.add_pm_conversation` when the sender is not already in `pm_conversations` and is not ignored.

**Rationale**: `apply_new_pm/3` is the single entry point for all incoming PMs. It already handles unread tracking, sounds, and notifications. Adding conversation auto-open here keeps all PM receipt logic colocated. The ignore check already exists in this function (via flood/auto-ignore), but we need to also check `IgnoreList.ignored?` for `:pm` type before auto-adding.

**Alternatives considered**:
- Separate PubSub handler: Would fragment PM handling across two locations.
- Client-side JS hook: Would lose server-side consistency and require additional push events.

## R3: Auto-Join on /join — Where to Hook

**Decision**: Modify the join result handler in `CommandDispatch.handle_dispatch_result/2` for `:join` results to call `AutoJoinList.add_entry/3` + persist, with guards for: (a) user is identified, (b) channel is not `#lobby`, (c) not currently in auto-join execution phase.

**Rationale**: `handle_dispatch_result({:ok, :join, channel, key})` is the single point where user-initiated joins complete successfully. The auto-join timer handler (`{:execute_autojoin, index}`) calls `join_channel/4` directly, bypassing `CommandDispatch`, so there's a natural separation — auto-join execution will never trigger the auto-add code path.

**Alternatives considered**:
- Hook in the Join command handler: This is in the domain layer and shouldn't have side effects on the auto-join list.
- Hook in `Helpers.join_channel/4`: This is called by both user-initiated joins AND auto-join execution, making circular prevention harder. The `CommandDispatch` approach naturally avoids this.

## R4: Auto-Remove on /part — Where to Hook

**Decision**: Modify the part result handler in `CommandDispatch.handle_dispatch_result/2` for `:part` results to call `AutoJoinList.remove_entry/2` + persist, with guard for user is identified.

**Rationale**: Same reasoning as R3 — `handle_dispatch_result({:ok, :part, ...})` is the single point for user-initiated parts. The corresponding `Helpers.part_channel/2` is called from here.

**Alternatives considered**:
- Hook in `Helpers.part_channel/2`: Would also fire on kick/disconnect cleanup.

## R5: PM Conversation Ordering

**Decision**: Change `pm_conversations` from a plain list to a list maintained in recency order. When a PM is sent or received, move (or add) the partner nick to the head of the list. On restore, the query returns partners in recency order which becomes the initial list.

**Rationale**: The treebar renders `pm_conversations` in list order. By maintaining recency order in the list itself, no sorting is needed at render time. The `Session.add_pm_conversation/2` function currently appends to the end — it needs to be modified to prepend (or move to head if already present).

**Alternatives considered**:
- Store timestamps alongside nicks in a keyword list or map: Over-complex. Position in the list is sufficient to convey recency.
- Sort at render time: Requires timestamps to be stored, adds per-render computation.

## R6: Circular Auto-Join Prevention

**Decision**: No explicit flag needed. The auto-join execution path (`{:execute_autojoin, index}` timer handler) calls `join_channel/4` directly. The auto-add logic is placed in `CommandDispatch.handle_dispatch_result/2` which is only reached via the `/join` command handler → `CommandDispatch.dispatch/3` path. These are two distinct code paths with no overlap.

**Rationale**: Architectural separation eliminates the need for runtime flags. Auto-join timer → `join_channel/4` (direct). User `/join` → `Parser.parse` → `CommandDispatch.dispatch` → `handle_dispatch_result` → `join_channel/4` + auto-add. The auto-add code is in `handle_dispatch_result`, which auto-join execution never passes through.

**Alternatives considered**:
- Socket assign flag `autojoining: true/false`: Adds state management complexity for no benefit given the natural code path separation.

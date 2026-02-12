# Research: Favorites / Bookmarks

## Decision 1: Data Persistence Pattern

**Decision**: Use the multi-row per-user pattern (like `AutojoinListEntry`) with a `favorites` table and a `FavoriteEntry` struct.

**Rationale**: Favorites are a list of entries per user with ordering, which maps exactly to the `autojoin_entries` pattern. The delete-all-then-reinsert transactional save approach used by `AutoJoinList` works well for ordered lists.

**Alternatives considered**:
- Single-row JSONB (like `SoundSettings`): Rejected because favorites are a list with variable length and ordering, not a fixed-key settings map. JSONB would complicate querying and indexing.
- Separate table per entry with individual CRUD: Rejected because the delete-all-reinsert pattern is simpler and already proven in the codebase.

## Decision 2: Password Encryption

**Decision**: Use `Plug.Crypto.MessageEncryptor` (AES-GCM) with keys derived from the application's `secret_key_base` via `Plug.Crypto.KeyGenerator`.

**Rationale**: `plug_crypto` is already a transitive dependency (via `plug`), so no new deps are needed. AES-GCM provides authenticated encryption (integrity + confidentiality). The `secret_key_base` is already configured in dev, test, and prod environments.

**Alternatives considered**:
- Erlang `:crypto` module directly: Rejected because `Plug.Crypto.MessageEncryptor` provides a higher-level, safer API with built-in key derivation and authenticated encryption.
- Store passwords in plain text: Rejected per FR-016 (encryption at rest required).
- bcrypt (one-way hashing): Not applicable — passwords must be recoverable for programmatic channel joins.

## Decision 3: Context Menu for Treebar

**Decision**: Add `phx-contextmenu` event handling to treebar channel items, reusing a similar pattern to the existing nicklist context menu but as a separate "treebar context menu" component.

**Rationale**: The treebar currently has no right-click support. Adding `phx-contextmenu` on channel `<li>` elements will capture right-click events. A new component (`TreebarContextMenu`) keeps concerns separated from the nicklist context menu.

**Alternatives considered**:
- Reuse existing `ContextMenu` component: Rejected because the context menu is specifically designed for nicknames (has nick-specific options like Query, Whois, Kick, etc.). Channel context actions (Add to Favorites, Channel Central) are a different domain.
- Add to Favorites via a different trigger only (e.g., menu bar): Rejected because right-click on treebar is the most intuitive discovery point per the spec.

## Decision 4: Favorites Menu in Menu Bar

**Decision**: Add a "Favorites" top-level menu to `MenuBar` component, passing the favorites list and current channels as attrs.

**Rationale**: The menu bar already has a clean pattern of top-level menus (File, Edit, View, Tools, Help). Adding "Favorites" between Tools and Help follows mIRC convention. Dynamic content (the list of favorites with checkmarks) requires passing attrs, which is consistent with how other components receive data.

**Alternatives considered**:
- Favorites as a sub-menu of Tools: Rejected because the spec explicitly calls for a top-level "Favorites" menu, matching classic mIRC UX.

## Decision 5: Relationship with Existing AutoJoin System

**Decision**: Favorites auto-join is independent of the existing `AutoJoinList` (perform system). Favorites with `auto_join: true` fire after the existing perform/autojoin system completes.

**Rationale**: The existing autojoin system (feature 009) is part of the "Perform" commands and is managed via the Perform dialog. Favorites auto-join is a separate concept with its own UI and storage. They should coexist — a channel can be in both the autojoin list (from Perform) and favorites. Duplicate join attempts are safely handled by the existing `join_channel` function which checks if already joined.

**Alternatives considered**:
- Merge favorites auto-join with existing autojoin system: Rejected because they serve different purposes and have different UIs. Merging would create coupling between unrelated features.

## Decision 6: Organize Favorites Dialog Pattern

**Decision**: Follow the `PerformDialog` pattern — a dialog with a list, selection state, and Up/Down/Edit/Remove buttons. Add/Edit opens a sub-dialog at z-index 210.

**Rationale**: The Perform dialog already implements exactly this UX pattern (list with selection, reordering, sub-dialogs for add/edit). Reusing the same approach ensures visual consistency and leverages proven code patterns.

**Alternatives considered**:
- OK/Cancel/Apply draft-state pattern (like SoundSettings): Rejected because favorites are a list, not a settings map. The list-with-buttons pattern is more appropriate.

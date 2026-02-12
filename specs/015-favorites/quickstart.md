# Quickstart: Favorites / Bookmarks

## Test Scenarios

### Scenario 1: Add a Favorite (US1 — Core)

1. Connect as user "Alice"
2. Right-click "#lobby" in the treebar
3. Select "Add to Favorites" from the context menu
4. Verify the Add Favorite dialog opens with "#lobby" pre-filled
5. Enter description: "Main lobby channel"
6. Check "Auto-join on connect"
7. Click OK
8. Open the "Favorites" menu in the menu bar
9. Verify "#lobby" appears with a checkmark (since Alice is in it)
10. Verify description shows next to the channel name

### Scenario 2: Join via Favorites Menu (US1 — Join)

1. Connect as user "Bob"
2. Add "#elixir" to favorites (via Add Favorite dialog)
3. Verify "#elixir" appears in Favorites menu WITHOUT a checkmark (not joined)
4. Click "#elixir" in the Favorites menu
5. Verify Bob joins "#elixir"
6. Open Favorites menu again
7. Verify "#elixir" now has a checkmark

### Scenario 3: Switch via Favorites Menu (US1 — Already Joined)

1. Connect as user "Carol", already in "#lobby"
2. Add "#lobby" to favorites
3. Join "#other" channel and switch to it
4. Click "#lobby" in the Favorites menu
5. Verify Carol switches to "#lobby" (no rejoin, no error)

### Scenario 4: Password Channel Favorite (US1 — Password)

1. Connect as user "Dave"
2. Create channel "#secret" with key "pass123"
3. Add "#secret" to favorites with password "pass123"
4. Part "#secret"
5. Click "#secret" in Favorites menu
6. Verify Dave joins "#secret" successfully using the saved password

### Scenario 5: Organize Favorites (US2 — Reorder)

1. Connect as user "Eve"
2. Add favorites: "#a", "#b", "#c" (in that order)
3. Open Organize Favorites from Favorites menu
4. Verify list shows: #a, #b, #c
5. Select "#c", click Move Up twice
6. Verify list shows: #c, #a, #b
7. Close dialog
8. Open Favorites menu
9. Verify order is: #c, #a, #b

### Scenario 6: Edit Favorite (US2 — Edit)

1. Connect as user "Frank"
2. Add "#dev" to favorites with description "Development"
3. Open Organize Favorites
4. Select "#dev", click Edit
5. Change description to "Development Channel"
6. Check "Auto-join on connect"
7. Click OK
8. Verify the updated description shows in the list

### Scenario 7: Remove Favorite (US2 — Remove)

1. Connect as user "Grace"
2. Add "#temp" to favorites
3. Open Organize Favorites
4. Select "#temp", click Remove
5. Verify "#temp" is removed from the list
6. Close dialog
7. Verify "#temp" no longer appears in the Favorites menu

### Scenario 8: Auto-Join on Connect (US3)

1. Register and identify as user "Heidi"
2. Add "#auto1" with auto-join enabled
3. Add "#auto2" with auto-join disabled
4. Add "#auto3" with auto-join enabled
5. Disconnect and reconnect, identify as "Heidi"
6. Verify "#auto1" and "#auto3" are joined automatically
7. Verify "#auto2" is NOT joined

### Scenario 9: Duplicate Detection (US4)

1. Connect as user "Ivan"
2. Add "#lobby" to favorites
3. Right-click "#lobby" in treebar, select "Add to Favorites"
4. Verify the dialog opens in edit mode showing existing data
5. Verify a notice indicates the channel is already a favorite

### Scenario 10: Wrong Password (US1 — Edge Case)

1. Connect as user "Judy"
2. Add "#locked" to favorites with password "oldpass"
3. Another user changes #locked's key to "newpass"
4. Click "#locked" in Favorites menu
5. Verify an error message appears: "Cannot join #locked: Wrong channel key"

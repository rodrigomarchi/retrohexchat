# Quickstart: User Information

## Scenario 1: Expanded /whois (US1)

### Setup
1. Start the application with two users: "Alice" and "Bob"
2. Both join #elixir
3. Alice sets a bio: `/bio Elixir enthusiast from Brazil`
4. Alice is registered with NickServ

### Test Steps
1. Bob types `/whois Alice`
2. Verify chat stream shows:
   - "Channels: #elixir" (and any other channels Alice is in)
   - "Shared channels: #elixir"
   - "Online for: X minutes"
   - "Idle for: X seconds"
   - "Registered: Yes"
   - "Bio: Elixir enthusiast from Brazil"
3. Alice sets away: `/away Gone to lunch`
4. Bob types `/whois Alice` again
5. Verify "Away: Gone to lunch" now appears

### Edge Case
- Bob types `/whois Bob` (self) — should show Bob's own info including bio

---

## Scenario 2: Idle Time Tracking (US2)

### Setup
1. Connect as "Alice"
2. Note the time

### Test Steps
1. Wait 2 minutes without sending anything
2. From another user, type `/whois Alice`
3. Verify idle time shows approximately "2 minutes"
4. Alice sends a message in any channel
5. Immediately type `/whois Alice` again
6. Verify idle time shows "less than a minute" or similar

---

## Scenario 3: Bio Set/View/Clear (US3)

### Test Steps
1. Type `/bio` — should show "No bio set"
2. Type `/bio Elixir enthusiast, loves retro computing` — should confirm bio set
3. Type `/bio` — should show the bio
4. Type `/bio clear` — should confirm bio cleared
5. Type `/bio` — should show "No bio set" again

### Persistence Test
1. Register with NickServ: `/ns register mypass`
2. Set bio: `/bio I love RetroHexChat`
3. Disconnect
4. Reconnect with same nickname
5. Identify: `/ns identify mypass`
6. Type `/bio` — should show "I love RetroHexChat"

### Truncation Test
1. Type `/bio` followed by 250 characters of text
2. Verify warning about truncation
3. Type `/bio` to view — should show exactly 200 characters

---

## Scenario 4: /whowas (US4)

### Setup
1. Connect as "Bob"
2. Join #elixir and #lobby

### Test Steps
1. Bob disconnects (close tab/window)
2. From Alice, type `/whowas Bob` within a few minutes
3. Verify output shows:
   - Last seen time (e.g., "2 minutes ago")
   - Channels: #elixir, #lobby
   - Quit message (if any)
4. Wait beyond 1 hour (or adjust TTL for testing)
5. Type `/whowas Bob` again
6. Verify "No whowas information available for Bob"

### Not Found Test
1. Type `/whowas NeverExisted`
2. Verify "No whowas information available for NeverExisted"

---

## Scenario 5: Double-Click Nicklist (US1)

### Test Steps
1. Connect as Bob in a channel with Alice
2. Double-click Alice's nickname in the nicklist
3. Verify /whois output for Alice appears in the chat stream
4. Verify it's the same output as typing `/whois Alice`

---

## Validation Checklist

- [ ] `/whois` shows all new fields (shared channels, online time, idle time, registered, away, bio)
- [ ] `/whois` on self works
- [ ] Fields with no value (no bio, not away) are omitted
- [ ] Double-click nicklist triggers /whois
- [ ] Idle time resets on message, PM, and command
- [ ] `/bio` set, view, clear all work
- [ ] Bio persists for registered users
- [ ] Bio truncation at 200 chars with warning
- [ ] `/whowas` shows info for recently disconnected users
- [ ] `/whowas` data expires after 1 hour
- [ ] `/whowas` for unknown nick shows not-found message
- [ ] Help topics for /whois, /whowas, /bio are present

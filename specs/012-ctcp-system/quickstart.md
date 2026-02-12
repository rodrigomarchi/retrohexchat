# Quickstart: CTCP (Client-to-Client Protocol)

**Feature**: 012-ctcp-system
**Date**: 2026-02-12

## Setup

```bash
# Ensure on feature branch
git checkout 012-ctcp-system

# Run migrations
cd apps/retro_hex_chat && mix ecto.migrate

# Start server
make server
```

## Test Scenarios

### Scenario 1: CTCP PING (Basic Round-Trip)

1. Open two browser tabs, connect as "Alice" and "Bob"
2. In Bob's tab, type: `/ctcp Alice ping`
3. **Expected in Bob's chat**: `* CTCP PING reply from Alice: <N>ms`
4. **Expected in Alice's chat**: `* CTCP PING request from Bob`

### Scenario 2: Self-CTCP PING

1. Connect as "TestUser"
2. Type: `/ctcp TestUser ping`
3. **Expected**: `* CTCP PING reply from TestUser: 0ms` (instant)

### Scenario 3: CTCP VERSION

1. Open two tabs as Alice and Bob
2. Bob types: `/ctcp Alice version`
3. **Expected in Bob's chat**: `* CTCP VERSION reply from Alice: RetroHexChat v1.0`
4. **Expected in Alice's chat**: `* CTCP VERSION request from Bob`

### Scenario 4: CTCP TIME

1. Open two tabs as Alice and Bob
2. Bob types: `/ctcp Alice time`
3. **Expected in Bob's chat**: `* CTCP TIME reply from Alice: 2026-02-12 10:30:00 UTC` (current server UTC time)

### Scenario 5: CTCP FINGER (Default)

1. Open two tabs as Alice and Bob
2. Alice sends a few messages, then waits 2 minutes
3. Bob types: `/ctcp Alice finger`
4. **Expected in Bob's chat**: `* CTCP FINGER reply from Alice: Alice - idle 2 minutes`

### Scenario 6: CTCP FINGER (Custom)

1. Connect as Alice, open Tools → CTCP Settings
2. Set custom FINGER text: "Alice - Elixir developer from Brazil"
3. Click Save
4. In Bob's tab: `/ctcp Alice finger`
5. **Expected in Bob's chat**: `* CTCP FINGER reply from Alice: Alice - Elixir developer from Brazil`

### Scenario 7: User Not Found

1. Connect as Bob
2. Type: `/ctcp OfflineUser ping`
3. **Expected**: `* User 'OfflineUser' not found`

### Scenario 8: CTCP Disabled (Timeout)

1. Connect as Alice, open Tools → CTCP Settings
2. Uncheck "Enable CTCP Responses"
3. In Bob's tab: `/ctcp Alice ping`
4. **Expected after ~10 seconds**: `* No CTCP reply from Alice (timed out)`

### Scenario 9: Rate Limiting

1. Connect as Bob and Alice
2. Bob rapidly types:
   - `/ctcp Alice ping` (1st — succeeds)
   - `/ctcp Alice version` (2nd — succeeds)
   - `/ctcp Alice time` (3rd — succeeds)
   - `/ctcp Alice finger` (4th — rate limited)
3. **Expected on 4th**: `* CTCP rate limit reached for Alice. Please wait before sending another request.`

### Scenario 10: Invalid CTCP Type

1. Connect as Bob
2. Type: `/ctcp Alice unknown`
3. **Expected**: `* Unknown CTCP type: unknown. Valid types: ping, version, time, finger`

### Scenario 11: Missing Arguments

1. Type: `/ctcp`
2. **Expected**: Usage syntax message
3. Type: `/ctcp Alice`
4. **Expected**: Usage syntax message

### Scenario 12: Case Insensitivity

1. Test all three forms:
   - `/ctcp Alice PING`
   - `/ctcp Alice ping`
   - `/ctcp Alice Ping`
2. **Expected**: All three produce identical results

### Scenario 13: No PM Windows Created

1. Connect as Bob and Alice
2. Bob sends: `/ctcp Alice ping`
3. **Verify**: No PM tab/window appears for either Bob or Alice
4. **Verify**: No treebar entry appears for the CTCP exchange
5. **Verify**: No notification sound plays

### Scenario 14: Settings Persistence (Registered User)

1. Connect as Alice, identify with NickServ
2. Open Tools → CTCP Settings
3. Set VERSION to "MyCoolClient v3.0", save
4. Disconnect Alice
5. Reconnect as Alice, identify again
6. Open CTCP Settings
7. **Expected**: VERSION shows "MyCoolClient v3.0" (persisted)

### Scenario 15: Settings Not Persisted (Guest)

1. Connect as guest "Guest_12345"
2. Open Tools → CTCP Settings
3. Set VERSION to "GuestClient", save
4. Disconnect
5. Reconnect as new guest
6. **Expected**: VERSION shows default "RetroHexChat v1.0" (not persisted)

## Verification Checklist

- [ ] PING shows round-trip latency in milliseconds
- [ ] Self-PING shows 0ms
- [ ] VERSION returns client string
- [ ] TIME returns server UTC time
- [ ] FINGER returns idle time or custom text
- [ ] Timeout fires after 10 seconds for disabled CTCP
- [ ] Rate limiting blocks 4th request within 30 seconds
- [ ] No PM windows or treebar entries created
- [ ] Settings dialog opens from Tools menu
- [ ] Settings persist for registered users
- [ ] Settings are session-only for guests
- [ ] Case-insensitive CTCP types
- [ ] Invalid type shows error with valid types list
- [ ] Missing arguments show usage syntax

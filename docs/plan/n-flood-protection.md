# Category N: Flood Protection

**Priority**: Yellow (Medium impact)
**Dependencies**: M (CTCP) for N2
**Existing**: N1 rate limit already implemented (5 msg/s per user, token bucket)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| N1 | Basic rate limit | Existing | 5 messages/second per user with token bucket algorithm |
| N2 | CTCP flood protection | New | Limit automatic CTCP responses to prevent flood |
| N3 | Configurable flood protection | New | Dialog to configure flood thresholds |
| N4 | Auto-ignore flooders | New | Automatically ignore users who exceed rate limits |
| N5 | Anti-spam filter | New | Configurable filter to block repeated messages or spam patterns |

## Dependencies Detail

- N1 (existing) provides the foundation
- N2 requires M (CTCP) to be implemented first
- N4 (auto-ignore) feeds into F (Ignore System) — auto-adds ignore entries
- N3 settings integrate into V (Options Dialog)

## Technical Notes (IRC/mIRC Reference)

- mIRC flood protection settings: Tools > Options > IRC > Flood
- Configurable parameters in mIRC: max lines, max bytes, time window, ignore duration
- mIRC can auto-ignore flooders for a configurable duration
- CTCP flood protection is separate from message flood protection in mIRC
- Some networks also implement server-side flood protection, but client-side protection is still important

---

## Spec Command

```
/speckit.specify "Flood Protection for RetroHexChat.

PROBLEM: While basic rate limiting exists (5 messages per second), users have no control over flood protection settings and no protection against specific abuse patterns like CTCP flooding, message spam, or repeated identical messages. Malicious or careless users can still degrade the experience through targeted abuse that falls within raw rate limits but is still disruptive.

EXISTING CONTEXT: Basic rate limiting is already implemented — 5 messages per second per user with automatic muting on violation. This feature extends protection with user-configurable thresholds, CTCP-specific limits, automatic ignoring, and spam pattern detection.

USER JOURNEY: A user notices that 'SpamBot' is sending repeated identical messages in #lobby, staying just under the rate limit but still being disruptive. The anti-spam filter detects the repetition (same message sent 3 times within 10 seconds) and automatically blocks further duplicates, showing the spammer a message: 'Your message was blocked (duplicate message detected)'. Other users see nothing.

When the spam continues with slight variations, the auto-ignore kicks in — after exceeding the flood threshold, SpamBot is automatically added to the user's ignore list for a configurable duration (default: 5 minutes). A system message appears: '* SpamBot has been auto-ignored for flooding (5 minutes)'. After the timeout, the ignore is automatically removed.

A user receiving excessive CTCP requests finds that the system limits CTCP replies to a maximum of 2 per 10 seconds, preventing their client from being used as a flood amplifier.

Users can customize all flood protection settings via a configuration dialog: message threshold (messages per time window), time window duration, auto-ignore duration, CTCP reply limit, spam filter sensitivity. Advanced users can fine-tune; casual users benefit from sensible defaults.

ACTORS: All flood protection runs per-user — each user's client independently detects and reacts to flooding. Configuration is per-user and persists for registered users.

EDGE CASES: Auto-ignore should not trigger for the user's own messages being rate-limited (that is a different mechanism). If a user is auto-ignored and manually un-ignored before the timer expires, the auto-ignore should not re-trigger immediately (cooldown period). Legitimate repeated messages (e.g., answering the same question in different channels) should not trigger spam detection if sent to different targets. System messages and service bot messages should be exempt from spam detection.

NEGATIVE REQUIREMENTS: Flood protection must NOT affect server/system messages. Auto-ignore must NOT notify the ignored user. Anti-spam must NOT block messages that merely contain similar words — only exact or near-exact duplicates within the time window.

SCOPE: In scope — CTCP flood protection, configurable flood thresholds dialog, auto-ignore on flood, anti-spam duplicate detection. Out of scope — server-side global flood protection (admin concern), network-wide rate limiting, IP-based blocking."
```

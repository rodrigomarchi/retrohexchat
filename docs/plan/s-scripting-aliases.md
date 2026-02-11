# Category S: Scripting & Aliases

**Priority**: Green (Low impact)
**Dependencies**: None (standalone)
**Existing**: None

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| S1 | Custom aliases | New | Users can create simple aliases: `/hi` -> `/me says hello everyone!` |
| S2 | Alias editor | New | Dialog to create/edit/remove custom aliases |
| S3 | Custom popup menus | New | Allow adding custom items to context menus |
| S4 | Auto-respond events | New | Configure simple automatic responses to events |
| S5 | Timer commands | New | /timer to execute commands at intervals |

## Dependencies Detail

- S is independent and can be implemented standalone
- S1 (aliases) extends the existing Commands context
- S3 (custom menus) extends existing context menu infrastructure
- S5 (timers) is standalone scheduling functionality

## Technical Notes (IRC/mIRC Reference)

- mIRC aliases: Tools > Aliases editor, one alias per line: `/hi /me says hello everyone!`
- mIRC aliases support identifiers: $nick, $chan, $1 $2 $3 (parameters), $me (own nick)
- mIRC popup menus: Tools > Popups, separate sections for channel, query, nicklist, status
- mIRC /timer: `/timer N R D command` — N=name, R=repetitions (0=infinite), D=delay in seconds
- mIRC scripting is a full language (mSL) — we implement only the simplified alias/timer subset

---

## Spec Command

```
/speckit.specify "Scripting & Aliases (Simplified) for RetroHexChat.

PROBLEM: Users who frequently type the same commands or phrases have no way to create shortcuts. Power users cannot automate repetitive actions like greeting newcomers, running periodic commands, or adding custom actions to context menus. Classic mIRC provides a powerful scripting system — we implement a simplified, safe subset: aliases, timers, and custom menu items.

USER JOURNEY: A user frequently greets channels by typing '/me says hello everyone!'. They open the Alias Editor dialog (via menu) and create an alias: name '/hi', expansion '/me says hello everyone!'. Now typing '/hi' in any channel automatically expands to the /me action.

For more dynamic aliases, the user creates: name '/greet', expansion '/me waves at $1' — where $1 is replaced with the first word after the alias command. Typing '/greet Alice' expands to '/me waves at Alice'. Available variables: $1 $2 $3... (positional arguments), $nick (own nickname), $chan (current channel name).

The user also wants a periodic reminder. They type '/timer remind 1800 /me reminds everyone: standup in 30 minutes' — this runs the command once after 1800 seconds. '/timer heartbeat repeat 600 /me is still here' repeats every 600 seconds. '/timer list' shows active timers. '/timer stop heartbeat' cancels a specific timer.

For convenience, the user adds a custom item to the nicklist right-click menu: 'Send greeting' that runs '/notice $1 Welcome to the channel!'. Now right-clicking any nick shows this custom option.

Auto-respond allows simple event-triggered commands: when someone joins #welcome, auto-send '/notice $nick Welcome to #welcome! Check the topic for rules.'. Each auto-respond rule has: trigger event, optional channel filter, and response command.

ACTORS: Any connected user (guest or registered). Aliases, timers, custom menus, and auto-responds persist for registered users.

EDGE CASES: Recursive aliases (alias A expands to alias B which expands to alias A) must be detected and rejected with an error. The maximum number of concurrent timers per user should be limited (e.g., 5) to prevent resource abuse. Auto-respond rules should have a rate limit to prevent spam (e.g., max 1 auto-greet per user per 60 seconds). Creating an alias that shadows a built-in command (like '/join') should show a warning but be allowed. Deleting an alias that is referenced by a custom menu item should not crash — the menu item should show 'alias not found' on use.

NEGATIVE REQUIREMENTS: Aliases must NOT be able to execute multiple commands in sequence (no command chaining — security concern). Auto-respond must NOT be triggerable by the user's own actions. Timer commands must NOT survive page reload (they are session-only). Custom popup menus must NOT replace built-in context menu items — only append to them.

SCOPE: In scope — alias system with variables ($1, $nick, $chan), alias editor dialog, /timer command (once and repeat), timer management (/timer list, /timer stop), custom popup menu items for nicklist and channel context menus, simple auto-respond rules. Out of scope — full scripting language, conditional logic, loops, file I/O, regex matching, event scripting beyond simple auto-respond."
```

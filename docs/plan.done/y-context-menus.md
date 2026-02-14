# Category Y: Context Menus

**Priority**: Red (Critical — rich interaction without commands)
**Dependencies**: None (builds on existing menu infrastructure)
**Existing**: Y1 nick context menu (context_menu.ex), Y2 treebar context menu (treebar_context_menu.ex)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| Y1 | Nick context menu (nicklist) | Existing | Right-click nick in nicklist shows PM, Whois, and op actions (kick, ban) |
| Y2 | Treebar context menu | Existing | Right-click channel in treebar shows "Add to Favorites" and custom items |
| Y3 | Nick context menu (chat area) | New | Right-click on a nickname in the chat message area shows same menu as nicklist |
| Y4 | URL context menu | New | Right-click on URL in chat: Open link, Copy URL, Save to URL List |
| Y5 | Channel context menu | New | Right-click on #channel in chat: Join, Add to Favorites, Copy name, Channel Info |
| Y6 | Message context menu | New | Right-click on chat area: Copy message, Copy selection, Quote/Reply, Ignore sender |
| Y7 | Extended treebar context menu | New | Add Mark as Read, Mute, Copy name, Leave channel, Channel settings to treebar menu |
| Y8 | Keyboard shortcuts in menus | New | Show shortcut hints aligned right in menu items (e.g., "Whois     Ctrl+W") |
| Y9 | Disabled states in menus | New | Gray out unavailable items (e.g., Kick when not op) with visual distinction |

## Dependencies Detail

- Y1 (existing) provides the base context menu component, positioning logic, and 98.css styling
- Y2 (existing) provides treebar-specific menu infrastructure
- Y3 extends Y1's menu to work on nicks rendered inside chat messages (different DOM target)
- Y4 (URL menu) relates to E (URL Catcher) for "Save to URL List" action
- Y6 (message menu) provides the "Quote/Reply" action — stubbed until AD (Message Interaction) is implemented
- Y8 (shortcut hints) depends on AA (Keyboard Shortcuts) for the actual shortcut registry
- Clickable/hoverable elements in chat (URLs, channels, nicks) are covered by Category Y2 (Interactive Elements), not here

## Technical Notes

- Existing context_menu.ex renders a 98.css-styled menu with PM, Whois options and op actions (kick, ban)
- Existing treebar_context_menu.ex renders Add to Favorites option for channel items
- Context menu positioning: must handle edge cases near viewport boundaries (flip up/left if needed)
- All context menus share the same 98.css visual pattern: raised border, separator lines, icons
- Nick detection in chat messages: need to identify nick text in rendered HTML — use data attributes on nick spans
- Browser default context menu must be suppressed (preventDefault) only on recognized targets
- Browser default context menu must be preserved for the input field (paste, spell-check)

---

## Spec Command

```
/speckit.specify "Context Menus for RetroHexChat.

PROBLEM: While basic right-click menus exist for the nicklist and treebar, there are no context menus for elements within the chat area itself — nicknames, URLs, channels, and the general message area. This forces users to manually type commands for common actions that should be one right-click away. Additionally, the existing treebar menu is minimal (only 'Add to Favorites'), menus don't show keyboard shortcuts, and there's no visual distinction for unavailable actions.

EXISTING CONTEXT: Two context menu components exist. (1) context_menu.ex provides a right-click menu on nicknames in the nicklist with PM, Whois, and operator actions (kick, ban). (2) treebar_context_menu.ex provides a right-click menu on channels in the treebar with 'Add to Favorites'. These provide the foundational 98.css styling, positioning logic, and DOM infrastructure for all new menus.

USER JOURNEY — NICK CONTEXT MENU IN CHAT: A user right-clicks on a nickname in the chat area. A 98.css-styled context menu appears with: Private Message, Whois, Copy Nick, separator, Ignore, Add to Address Book, Set Nick Color. If the user is a channel operator, additional items appear below a separator: Kick, Ban, Give Voice (+v), Give Op (+o). Each menu item shows its keyboard shortcut aligned to the right. Items that are not available (e.g., Kick when not an op) appear grayed out and are not clickable.

USER JOURNEY — URL AND CHANNEL CONTEXT MENUS: Right-clicking a URL in chat shows: Open Link, Copy URL, Save to URL List. Right-clicking a #channel name shows: Join Channel, Add to Favorites, Copy Channel Name, Channel Info.

USER JOURNEY — MESSAGE CONTEXT MENU: Right-clicking on the general chat area (not on a specific nick or URL) shows: Copy Message, Copy Selected Text, Quote/Reply, Ignore Sender. If the message contains a URL, URL-specific items also appear.

USER JOURNEY — EXTENDED TREEBAR MENU: Right-clicking a channel in the treebar shows the extended menu: Mark as Read, Mute Channel, Add to Favorites, Copy Name, separator, Leave Channel, Channel Settings.

ACTORS: Any connected user (guest or registered) can use context menus. Op-specific menu items only appear for operators. Menus respect ignore lists and channel permissions.

EDGE CASES: Context menus near the edge of the viewport must reposition (flip up/left) to stay visible. Right-clicking while another context menu is open should close the first and open the new one. The browser's default context menu must be preserved for the input field (paste, spell-check). Right-clicking on a system message (join/part/quit) should show the message context menu but without 'Ignore sender'. If multiple elements overlap (e.g., a nick inside a URL), the most specific element wins.

NEGATIVE REQUIREMENTS: Context menus must NOT appear for the input field — browser default menu must be preserved there. Context menus must NOT show op actions to non-operators under any circumstance. The 'Quote/Reply' action must NOT crash if Category AD (Message Interaction) is not yet implemented — it should be disabled/hidden until then.

SCOPE: In scope — context menus for nicks in chat, URLs in chat, #channels in chat, general chat area, extended treebar menu, keyboard shortcut hints in menus, disabled/grayed states for unavailable items. Out of scope — clickable/hoverable interactive elements in chat (that is Category Y2 Interactive Elements), context menus in dialogs, custom menu items via scripting."
```

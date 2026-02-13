# Category AE: Accessibility (a11y)

**Priority**: Red (Critical — cross-cutting, ensures usability for all)
**Dependencies**: None (cross-cutting, can be applied at any time)
**Existing**: None (new category, though 98.css provides some inherent high contrast)

## Items

| # | Feature | Status | Description |
|---|---------|--------|-------------|
| AE1 | Keyboard-only navigation | New | All features accessible without a mouse — full Tab/Enter/Esc navigation |
| AE2 | Logical tab order | New | Tab flows: treebar → chat → input → nicklist, with visible focus indicators |
| AE3 | ARIA labels and roles | New | All interactive elements have appropriate ARIA labels, roles, and states |
| AE4 | Screen reader support | New | Chat area with role="log" and aria-live, new messages announced to screen readers |
| AE5 | Focus visible indicators | New | Clear focus ring/outline on all focusable elements (not just browser default) |
| AE6 | Font scaling / rem units | New | All font sizes and spacing use rem units, respecting browser zoom settings |
| AE7 | Reduced motion support | New | Respect prefers-reduced-motion — disable animations, flashes, title blink |

## Dependencies Detail

- AE1-AE7 are cross-cutting — they affect every component in the application
- AE1 (keyboard navigation) complements AA (Keyboard Shortcuts) — AA adds shortcuts, AE ensures base navigation works
- AE2 (tab order) requires reviewing all components' tabindex attributes
- AE3 (ARIA) must be applied to all existing components and all new components going forward
- AE4 (screen reader) specifically targets chat message area, dialogs, and toasts
- AE5 (focus visible) should use a consistent focus style across all 98.css-styled elements
- AE6 (rem units) requires auditing all CSS for px values that should be rem
- AE7 (reduced motion) requires wrapping all CSS animations in @media (prefers-reduced-motion: no-preference)

## Technical Notes

- 98.css provides naturally high contrast (dark text on light gray backgrounds, sunken/raised borders)
- Tab order: use semantic HTML order + tabindex where needed, avoid tabindex > 0
- ARIA patterns: role="log" for chat, role="listbox" for nicklist, role="tree" for treebar
- aria-live="polite" for new messages, "assertive" for error notifications
- Focus indicators: use CSS :focus-visible with a consistent outline style (e.g., 2px dotted black, 98.css-compatible)
- Font scaling: audit all components for hardcoded px values in font-size, line-height, padding, margin
- Reduced motion: use CSS @media (prefers-reduced-motion: reduce) to disable transitions, animations, and flashing
- Color not sole indicator: existing patterns already use icons + text (connection status, user status)
- Test with screen readers: VoiceOver (macOS), NVDA/JAWS (Windows), Orca (Linux)

---

## Spec Command

```
/speckit.specify "Accessibility (a11y) for RetroHexChat.

PROBLEM: The application currently has no systematic accessibility support. While 98.css provides inherent high contrast, there are no ARIA labels on interactive elements, no logical tab order for keyboard navigation, no screen reader support for the chat stream, no consistent focus indicators, hardcoded pixel values that do not scale with browser zoom, and no respect for the prefers-reduced-motion media query. Users who rely on keyboards, screen readers, or accessibility settings cannot effectively use the application.

EXISTING CONTEXT: The application uses 98.css which provides naturally high-contrast visual design (dark text on light gray backgrounds, clear sunken/raised borders). Some interactive elements have basic keyboard handling (the input field, dialog buttons). The Windows 98 aesthetic already includes visually distinct interactive elements (buttons look raised, inputs look sunken). However, no systematic accessibility audit or ARIA implementation has been done.

USER JOURNEY — KEYBOARD NAVIGATION: A user who cannot use a mouse opens RetroHexChat. They press Tab and focus moves logically through the interface: first to the treebar (channel list), where arrow keys navigate between channels and Enter selects one. Tab again moves to the chat area. Tab again to the input field where they can type. Tab again to the nicklist where arrow keys navigate users. Shift+Tab reverses the order. Every focused element has a clear, visible outline that matches the 98.css aesthetic. All dialogs are navigable with Tab (between fields/buttons) and dismissable with Esc. All dropdown menus support arrow key navigation.

USER JOURNEY — SCREEN READER: A visually impaired user navigates to RetroHexChat with a screen reader. The page structure is announced: 'RetroHexChat — channel list, navigation', 'Chat messages, log region', 'Message input, text field', 'User list, listbox'. As new messages arrive, the screen reader announces them: 'Mario says: Hello everyone!'. System messages are announced differently: 'System: Alice has joined #general'. The treebar is announced as a tree with expandable items. Dialogs are announced with their titles. Error messages are announced immediately (assertive). The user always knows where they are and what is happening.

USER JOURNEY — FONT SCALING: A user with low vision has their browser zoom set to 150%. All text, spacing, and UI elements scale proportionally. Nothing overflows, truncates unexpectedly, or breaks layout. The 98.css window borders, buttons, and scrollbars scale appropriately. The chat remains readable and functional at zoom levels from 100% to 200%.

USER JOURNEY — REDUCED MOTION: A user with vestibular sensitivity has prefers-reduced-motion enabled in their OS settings. All animations are disabled: no title bar flashing, no treebar pulse effects, no toast slide-in animations, no spinner rotations (replaced with static indicators). Transitions are instant rather than animated. The application is fully functional without any motion.

ACTORS: Accessibility features affect all users. They are always active (not toggleable) and follow OS/browser preferences where applicable (reduced motion, font scaling). No user action is required to enable accessibility — it is the default.

EDGE CASES: Tab order must be maintained correctly when dialogs open and close (focus trap inside modals, restore focus on close). Dynamic content (new messages, notifications) must not steal focus from the current element. ARIA live regions must not be too verbose — batch rapid messages to avoid screen reader fatigue. Custom dropdown menus must implement the full ARIA combobox/listbox pattern. The treebar with nested items must implement the ARIA tree pattern correctly. Focus must be visible even on elements that use 98.css's custom styling (buttons, tabs, tree items). Browser extensions that modify accessibility should not conflict.

NEGATIVE REQUIREMENTS: Accessibility features must NOT be optional or toggleable — they are always present. ARIA labels must NOT be redundant with visible text (avoid 'Button: Submit button'). Focus indicators must NOT be removed (outline: none) for aesthetic reasons. Keyboard navigation must NOT trap the user in any component (except modal dialogs). Screen reader announcements must NOT include formatting codes or internal markup.

SCOPE: In scope — keyboard-only navigation for all features, logical tab order (treebar → chat → input → nicklist), ARIA labels and roles for all interactive elements, screen reader support with role='log' and aria-live, consistent focus-visible indicators, rem-based font sizing for all components, prefers-reduced-motion support. Out of scope — high-contrast theme toggle (98.css is already high contrast), RTL language support, voice control, captioning for audio content, WCAG AAA compliance (target AA)."
```

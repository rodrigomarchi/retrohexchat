# RetroHexChatWeb

Phoenix LiveView web layer with retro aesthetic.

### LiveView Screens

- **DesktopLive** (`/`, `/c/:channel` and every page of the site) — the one
  desktop: the chat, and each page, help, the archive, invitations and the
  sign-in window (`/connect`) as windows over it
- **ChannelListLive** (`/channels`) — Channel browser

### Components

57 function components rendering retro-styled semantic HTML including Window, Dialog, ChatMessage, Nicklist, StatusBar, Toolbar, TabBar, EmojiPicker, ContextMenu, and many more.

### JavaScript Hooks

31 hooks following the "hook = wiring, lib = logic" pattern with 34 extracted lib modules. Core UI logic lives server-side via LiveView.

See the [project README](../../README.md) for full documentation.

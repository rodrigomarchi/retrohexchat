# RetroHexChatWeb

Phoenix LiveView web layer with retro aesthetic.

### LiveView Screens

- **ConnectLive** (`/`) — Nickname entry dialog
- **ChatLive** (`/chat`) — Main MDI chat interface
- **ChannelListLive** (`/channels`) — Channel browser

### Components

15 function components rendering retro-styled semantic HTML: Window, TitleBar, MenuBar, Toolbar, Treebar, ChatMessage, Nicklist, StatusBar, CommandPalette, ContextMenu, SearchBar, ScrollLoader, Dialog.

### JavaScript Hooks

4 minimal hooks (all UI logic lives server-side via LiveView): ScrollHook, CommandPaletteHook, KeyboardHook, SoundHook.

See the [project README](../../README.md) for full documentation.

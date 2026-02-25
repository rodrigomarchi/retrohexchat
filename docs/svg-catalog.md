# SVG Catalog — Icons & Diagrams

All SVGs extracted and organized in the SVG consolidation effort.

## New Icon Submodules

### Icons.Formatting (14x14)

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/formatting.ex`

| Function | Description |
|----------|-------------|
| `icon_fmt_bold` | Bold B |
| `icon_fmt_italic` | Italic I |
| `icon_fmt_underline` | Underline U |
| `icon_fmt_color` | Color grid 3x3 |
| `icon_fmt_reverse` | Reverse R/R split |
| `icon_fmt_reset` | Aa with red line |
| `icon_fmt_strip` | Circle with slash |
| `icon_fmt_emoji` | Smiley face |

### Icons.Games (32x32)

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/games.ex`

| Function | Description |
|----------|-------------|
| `game_icon` | Dispatcher by `game_id` attr |
| `icon_game_pong` | Hex Pong — paddle + ball |
| `icon_game_trails` | Light Trails — grid + trails |
| `icon_game_tanks` | Pixel Tanks — top-down tank |
| `icon_game_space` | Star Duel — spaceship |
| `icon_game_gravity` | Gravity Well — star with rings |
| `icon_game_debris` | Debris Field — ship among rocks |
| `icon_game_breakout` | Block Breakers — paddle + blocks |
| `icon_game_warlords` | Hex Warlords — shield + fireball |
| `icon_game_raid` | Hex Raid — jet + river |
| `icon_game_boxing` | Hex Boxing — ring with fists |
| `icon_game_outlaw` | Hex Outlaw — crossed revolvers |
| `icon_game_generic` | Generic gamepad (fallback) |

## New Icons in Existing Submodules (16x16)

### Communication

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/communication.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_disconnect` | Two circles + red X |
| `icon_btn_connect_lightning` | Two circles + lightning bolt |
| `icon_btn_connect_disabled` | Gray circles (disabled state) |
| `icon_btn_channel_list` | List with # symbol |
| `icon_btn_toggle_conversations` | Panel with lines |
| `icon_btn_toggle_nicklist` | Panel with people |
| `icon_btn_auto_respond` | Speech bubble + arrow |
| `icon_btn_url_catcher` | Globe with dot |
| `icon_btn_ctcp` | Bidirectional arrows |
| `icon_btn_channel_central` | House |

### Tools

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/tools.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_find` | Magnifying glass |
| `icon_btn_settings` | Gear |
| `icon_btn_address_book` | Notebook with lines |
| `icon_btn_alias_editor` | A= with pencil |
| `icon_btn_custom_menus` | Lines + arrow |
| `icon_btn_highlight_words` | Marker/highlighter |

### Security

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/security.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_ignore_list` | Person with ban circle |
| `icon_btn_flood_protection` | Shield with lock |

### Alerts

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/alerts.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_dnd` | Moon (normal) |
| `icon_btn_dnd_active` | Moon + red slash (active) |
| `icon_btn_help_topics` | Question mark in circle |

### Code

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/code.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_perform` | Play + gear |
| `icon_btn_bot_management` | Gear with circle |
| `icon_dialog_admin_console` | Terminal >_ |

### Media

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/media.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_sounds` | Speaker with waves |

### Hardware

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/hardware.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_bell` | Notification bell |

### Files

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/files.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_keyboard` | Keyboard |

## Diagrams

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/diagrams.ex`

| Function | Description | Extracted from |
|----------|-------------|----------------|
| `diagram_p2p_flow` | P2P connection flow (4-step vertical flowchart) | `landing_html/how_it_works.html.heex` |
| `diagram_security_layers` | Security layers (HTTPS/TLS + DTLS-SRTP) | `landing_html/how_it_works.html.heex` |
| `diagram_p2p_architecture` | P2P architecture (Alice-Bob with signaling) | `landing_html/about.html.heex` |
| `diagram_voice_call_mockup` | Retro voice call window mockup | `landing_html/features.html.heex` |

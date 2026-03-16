# SVG Catalog — Icons & Diagrams

All SVGs extracted and organized in the SVG consolidation effort.

## New Icon Submodules

### Icons.Formatting (14x14)

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/formatting.ex`

| Function | Description |
|----------|-------------|
| `icon_fmt_bold` | Bold B **[DONE]** |
| `icon_fmt_italic` | Italic I **[DONE]** |
| `icon_fmt_underline` | Underline U **[DONE]** |
| `icon_fmt_color` | Color grid 3x3 **[DONE]** |
| `icon_fmt_reverse` | Reverse R/R split **[DONE]** |
| `icon_fmt_reset` | Aa with red line **[DONE]** |
| `icon_fmt_strip` | Circle with slash **[DONE]** |
| `icon_fmt_emoji` | Smiley face **[DONE]** |

### Icons.Games (32x32)

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/games.ex`

| Function | Description |
|----------|-------------|
| `game_icon` | Dispatcher by `game_id` attr **[DONE]** |
| `icon_game_pong` | Hex Pong — paddle + ball **[DONE]** |
| `icon_game_trails` | Light Trails — grid + trails **[DONE]** |
| `icon_game_tanks` | Pixel Tanks — top-down tank **[DONE]** |
| `icon_game_space` | Star Duel — spaceship **[DONE]** |
| `icon_game_gravity` | Gravity Well — star with rings **[DONE]** |
| `icon_game_debris` | Debris Field — ship among rocks **[DONE]** |
| `icon_game_breakout` | Block Breakers — paddle + blocks **[DONE]** |
| `icon_game_warlords` | Hex Warlords — shield + fireball **[DONE]** |
| `icon_game_raid` | Hex Raid — jet + river **[DONE]** |
| `icon_game_boxing` | Hex Boxing — ring with fists **[DONE]** |
| `icon_game_outlaw` | Hex Outlaw — crossed revolvers **[DONE]** |
| `icon_game_invaders` | Hex Invaders — Space Invader silhouette **[DONE]** |
| `icon_game_generic` | Generic gamepad (fallback) **[DONE]** |

## New Icons in Existing Submodules (16x16)

### Communication

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/communication.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_disconnect` | Two circles + red X **[DONE]** |
| `icon_btn_connect_lightning` | Two circles + lightning bolt **[DONE]** |
| `icon_btn_connect_disabled` | Gray circles (disabled state) **[DONE]** |
| `icon_btn_channel_list` | List with # symbol **[DONE]** |
| `icon_btn_toggle_conversations` | Panel with lines **[DONE]** |
| `icon_btn_toggle_nicklist` | Panel with people **[DONE]** |
| `icon_btn_auto_respond` | Speech bubble + arrow **[DONE]** |
| `icon_btn_url_catcher` | Globe with dot **[DONE]** |
| `icon_btn_channel_central` | House **[DONE]** |

### Tools

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/tools.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_find` | Magnifying glass **[DONE]** |
| `icon_btn_settings` | Gear **[DONE]** |
| `icon_btn_address_book` | Notebook with lines **[DONE]** |
| `icon_btn_alias_editor` | A= with pencil **[DONE]** |
| `icon_btn_custom_menus` | Lines + arrow **[DONE]** |
| `icon_btn_highlight_words` | Marker/highlighter **[DONE]** |

### Security

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/security.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_ignore_list` | Person with ban circle **[DONE]** |
| `icon_btn_flood_protection` | Shield with lock **[DONE]** |

### Alerts

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/alerts.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_dnd` | Moon (normal) **[DONE]** |
| `icon_btn_dnd_active` | Moon + red slash (active) **[DONE]** |
| `icon_btn_help_topics` | Question mark in circle **[DONE]** |

### Code

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/code.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_perform` | Play + gear **[DONE]** |
| `icon_btn_bot_management` | Gear with circle **[DONE]** |
| `icon_dialog_admin_console` | Terminal >_ **[DONE]** |

### Media

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/media.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_sounds` | Speaker with waves **[DONE]** |

### Hardware

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/hardware.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_bell` | Notification bell **[DONE]** |

### Files

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/files.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_keyboard` | Keyboard **[DONE]** |

## Diagrams

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/diagrams.ex`

| Function | Description | Extracted from |
|----------|-------------|----------------|
| `diagram_p2p_flow` | P2P connection flow (4-step vertical flowchart) **[DONE]** | `landing_html/how_it_works.html.heex` |
| `diagram_security_layers` | Security layers (HTTPS/TLS + DTLS-SRTP) **[DONE]** | `landing_html/how_it_works.html.heex` |
| `diagram_p2p_architecture` | P2P architecture (Alice-Bob with signaling) **[DONE]** | `landing_html/about.html.heex` |
| `diagram_voice_call_mockup` | Retro voice call window mockup **[DONE]** | `landing_html/features.html.heex` |

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

### Icons.Flags (14x14)

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/flags.ex`

National flags for the language menu — one per supported locale, drawn as a
12×9 field inside a 1px outline. `flag_icon` dispatches by `locale` attr and
falls back to the globe for unknown codes.

| Function | Description |
|----------|-------------|
| `flag_icon` | Dispatcher by `locale` attr **[DONE]** |
| `icon_flag_en` | United States (en) **[DONE]** |
| `icon_flag_pt_br` | Brazil (pt_BR) **[DONE]** |
| `icon_flag_pt_pt` | Portugal (pt_PT) **[DONE]** |
| `icon_flag_es` | Spain (es) **[DONE]** |
| `icon_flag_fr` | France (fr) **[DONE]** |
| `icon_flag_de` | Germany (de) **[DONE]** |
| `icon_flag_ja` | Japan (ja) **[DONE]** |
| `icon_flag_zh_hans` | China (zh_hans) **[DONE]** |
| `icon_flag_zh_hant` | Taiwan (zh_hant) **[DONE]** |
| `icon_flag_id` | Indonesia (id) **[DONE]** |
| `icon_flag_ar` | Saudi Arabia (ar) **[DONE]** |
| `icon_flag_ru` | Russia (ru) **[DONE]** |
| `icon_flag_hi` | India (hi) **[DONE]** |
| `icon_flag_ko` | South Korea (ko) **[DONE]** |
| `icon_flag_tr` | Turkey (tr) **[DONE]** |
| `icon_flag_vi` | Vietnam (vi) **[DONE]** |
| `icon_flag_bn` | Bangladesh (bn) **[DONE]** |
| `icon_flag_ur` | Pakistan (ur) **[DONE]** |
| `icon_flag_it` | Italy (it) **[DONE]** |
| `icon_flag_pl` | Poland (pl) **[DONE]** |
| `icon_flag_nl` | Netherlands (nl) **[DONE]** |

### Icons.CallControls (64x64 source, 32/64 rendered)

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/call_controls.ex`

| Function | Description |
|----------|-------------|
| `icon_call_microphone` | Detailed call microphone **[DONE]** |
| `icon_call_mute` | Muted microphone with red slash **[DONE]** |
| `icon_call_camera` | Detailed call camera **[DONE]** |
| `icon_call_camera_off` | Disabled camera with red slash **[DONE]** |
| `icon_call_screen_share` | Monitor with share arrow **[DONE]** |
| `icon_call_phone_end` | Destructive hang-up phone **[DONE]** |
| `icon_call_pip` | Picture-in-picture monitor **[DONE]** |
| `icon_call_devices` | Device selector with signal waves **[DONE]** |
| `icon_call_layout_auto` | Auto/grid layout control **[DONE]** |
| `icon_call_layout_focus` | Focus layout control **[DONE]** |
| `icon_call_layout_split` | Split/grid layout control **[DONE]** |
| `icon_call_layout_speaker` | Speaker layout control **[DONE]** |
| `icon_call_layout_compact` | Compact layout control **[DONE]** |
| `icon_call_self_view` | Self-view/PiP control **[DONE]** |
| `icon_call_stats` | Conference/P2P statistics bars **[DONE]** |
| `icon_call_mini` | Minimize call window **[DONE]** |
| `icon_call_expand` | Expand call window **[DONE]** |
| `icon_call_webrtc` | WebRTC connection nodes **[DONE]** |
| `icon_call_reactions` | Reaction flyout trigger **[DONE]** |
| `icon_call_more` | Participant action flyout trigger **[DONE]** |
| `icon_call_raise_hand` | Raise-hand control **[DONE]** |
| `icon_call_participants` | Participants control **[DONE]** |
| `icon_call_lock` | Conference lock/moderation shield **[DONE]** |
| `icon_call_close` | Clear/close focus control **[DONE]** |
| `icon_call_reaction_heart` | Call heart reaction **[DONE]** |
| `icon_call_reaction_thumbs_up` | Call thumbs-up reaction **[DONE]** |
| `icon_call_reaction_clap` | Call clap reaction **[DONE]** |
| `icon_call_reaction_laugh` | Call laugh reaction **[DONE]** |
| `icon_call_reaction_sparkle` | Call sparkle reaction **[DONE]** |

## New Icons in Existing Submodules (16x16)

### People

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/people.ex`

| Function | Description |
|----------|-------------|
| `icon_dialog_profile` | ID card with portrait + bio lines — Profile title bar and taskbar **[DONE]** |
| `icon_btn_profile` | ID card outline, toolbar weight — Profile menu/start menu/toolbar **[DONE]** |
| `icon_dialog_user_modes` | Person + mode flag — User Modes title bar and taskbar **[DONE]** |
| `icon_btn_user_modes` | Person + mode flag, toolbar weight — User Modes menu/start menu/toolbar **[DONE]** |

### Communication

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/communication.ex`

| Function | Description |
|----------|-------------|
| `icon_p2p_route` | Animated route strip used by the compact P2P network diagram **[DONE]** |
| `icon_btn_disconnect` | Two circles + red X **[DONE]** |
| `icon_btn_connect_lightning` | Two circles + lightning bolt **[DONE]** |
| `icon_btn_connect_disabled` | Gray circles (disabled state) **[DONE]** |
| `icon_btn_channel_list` | List with # symbol **[DONE]** |
| `icon_btn_toggle_conversations` | Panel with lines **[DONE]** |
| `icon_btn_toggle_nicklist` | Panel with people **[DONE]** |
| `icon_btn_auto_respond` | Speech bubble + arrow **[DONE]** |
| `icon_btn_url_catcher` | Globe with dot **[DONE]** |
| `icon_btn_channel_central` | House **[DONE]** |
| `icon_dialog_autojoin` | Hash + green entry arrow — Auto-Join title bar and taskbar **[DONE]** |
| `icon_btn_autojoin` | Hash + entry arrow, toolbar weight — Auto-Join menu/start menu/toolbar **[DONE]** |
| `icon_globe` | Wireframe globe (browser/locale/timezone fields) **[DONE]** |

### Tools

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/tools.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_find` | Magnifying glass **[DONE]** |
| `icon_btn_settings` | Gear **[DONE]** |
| `icon_btn_address_book` | Notebook with lines **[DONE]** |
| `icon_btn_alias_editor` | A= with pencil **[DONE]** |
| `icon_btn_custom_menus` | Lines + arrow **[DONE]** |
| `icon_btn_timers` | Stopwatch/clock hands **[DONE]** |
| `icon_btn_highlight_words` | Marker/highlighter **[DONE]** |

### Security

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/security.ex`

| Function | Description |
|----------|-------------|
| `icon_btn_ignore_list` | Person with ban circle **[DONE]** |
| `icon_btn_flood_protection` | Shield with lock **[DONE]** |
| `icon_tab_registration` | Shield tab icon for Channel Central registration **[DONE]** |

### Alerts

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/alerts.ex`

| Function | Description |
|----------|-------------|
| `icon_dialog_away` | Clock — Away window title bar and taskbar **[DONE]** |
| `icon_btn_away` | Clock outline, toolbar weight — Away menu/start menu/toolbar **[DONE]** |
| `icon_btn_dnd` | Moon (normal) **[DONE]** |
| `icon_btn_dnd_active` | Moon + red slash (active) **[DONE]** |
| `icon_btn_help_topics` | Question mark in circle **[DONE]** |

### Symbols

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/symbols.ex`

| Function | Description |
|----------|-------------|
| `icon_thumbs_up` | Pixel thumbs-up reaction for channel conferences **[DONE]** |
| `icon_clap` | Pixel clapping-hands reaction for channel conferences **[DONE]** |
| `icon_laugh` | Pixel laughing-face reaction for channel conferences **[DONE]** |
| `icon_sparkle` | Pixel sparkle reaction for channel conferences **[DONE]** |
| `icon_pin` | Push pin for pinned conference participants **[DONE]** |
| `icon_sword` | 8-bit upright sword (currentColor) for the space virtual pad attack button **[DONE]** |

### Marks

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/marks.ex`

| Function | Description |
|----------|-------------|
| `icon_fullscreen_enter` | Corner brackets expanding outward (currentColor) for the space fullscreen toggle **[DONE]** |
| `icon_fullscreen_exit` | Windowed-mode square outline (currentColor) for the space fullscreen toggle **[DONE]** |

### Arrows

`apps/retro_hex_chat_web/lib/retro_hex_chat_web/components/icons/arrows.ex`

| Function | Description |
|----------|-------------|
| `icon_pad_up` | 8-bit D-pad up triangle (currentColor) for the space virtual pad **[DONE]** |
| `icon_pad_down` | 8-bit D-pad down triangle (currentColor) for the space virtual pad **[DONE]** |
| `icon_pad_left` | 8-bit D-pad left triangle (currentColor) for the space virtual pad **[DONE]** |
| `icon_pad_right` | 8-bit D-pad right triangle (currentColor) for the space virtual pad **[DONE]** |

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
| `icon_browser` | Generic retro browser window for P2P whois/browser surfaces **[DONE]** |
| `icon_operating_system` | Generic OS tile grid for P2P whois/device surfaces **[DONE]** |

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

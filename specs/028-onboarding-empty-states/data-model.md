# Data Model: Onboarding & Empty States

**Feature**: 028-onboarding-empty-states
**Date**: 2026-02-14

## Overview

This feature requires **no database migrations**. All onboarding state is client-side (localStorage). Empty states are purely presentational — they render conditionally based on existing data (empty lists/streams).

## Client-Side State

### localStorage Keys

| Key | Type | Values | Set When | Read When |
|-----|------|--------|----------|-----------|
| `retro_hex_chat_onboarding_complete` | string | `"true"` | Wizard completed, skipped, or dismissed | ConnectLive mount (via JS hook) |

### ConnectLive Assigns (New)

| Assign | Type | Default | Description |
|--------|------|---------|-------------|
| `wizard_mode` | boolean | `false` | Whether to show wizard or simple connect form |
| `wizard_step` | atom | `:welcome` | Current wizard step: `:welcome`, `:server`, `:channels` |
| `wizard_nickname` | string | `""` | Nickname entered in Step 1 |
| `wizard_server` | string | `"irc.retro.chat"` | Server address in Step 2 |
| `wizard_port` | integer | `6697` | Server port in Step 2 |
| `wizard_ssl` | boolean | `true` | SSL enabled in Step 2 |
| `wizard_connecting` | boolean | `false` | Connection attempt in progress |
| `wizard_connect_error` | string \| nil | `nil` | Connection error message |
| `wizard_channels` | list | `[]` | Available channels with user counts |
| `wizard_selected_channels` | list | `[]` | User-selected channels in Step 3 |
| `wizard_custom_channel` | string | `""` | Custom channel name input in Step 3 |

### ChatLive Assigns (New)

| Assign | Type | Default | Description |
|--------|------|---------|-------------|
| `show_onboarding_tip` | boolean | `false` | Whether to show post-wizard banner |

## Existing Data Dependencies

### Empty State Conditions

| Component | Condition for Empty State | Data Source (existing assign) |
|-----------|--------------------------|-------------------------------|
| Channel messages | Stream/list is empty for active channel | `@messages` (stream) |
| Nicklist | User list is empty | `@channel_users` |
| Treebar | No joined channels | `@channels` |
| URL Catcher | No captured URLs | URL catcher list assign |

## Entity Relationships

```text
localStorage
  └── retro_hex_chat_onboarding_complete ──→ ConnectLive.wizard_mode

ConnectLive (wizard flow)
  ├── Step 1 (:welcome) ──→ wizard_nickname
  ├── Step 2 (:server)  ──→ wizard_server, wizard_port, wizard_ssl
  └── Step 3 (:channels) ──→ wizard_selected_channels
                              │
                              ▼
                    push_navigate to /chat
                    ?nickname=X&join=ch1,ch2&onboarded=true
                              │
                              ▼
                    ChatLive mount
                    └── show_onboarding_tip = true
```

## State Transitions

### Wizard Step Machine

```text
[mount] ──→ :welcome ──→ :server ──→ :channels ──→ [complete → navigate to /chat]
               │            │            │
               ▼            ▼            ▼
            [dismiss]    [dismiss]    [skip/dismiss]
               │            │            │
               └────────────┴────────────┘
                            │
                   Set localStorage flag
                   Navigate to /chat (or stay on connect)
```

### Empty State Lifecycle

```text
[container empty] ──→ Show empty state placeholder
                            │
                      [content arrives]
                            │
                            ▼
                   LiveView re-render removes placeholder
                   (automatic — no explicit state transition)
```

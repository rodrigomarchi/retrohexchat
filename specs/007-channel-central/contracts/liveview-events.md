# Contract: LiveView Events for Channel Central

**Feature**: 007-channel-central
**Module**: `RetroHexChatWeb.Live.ChatLive`

## New Assigns

| Assign                        | Type                | Default   | Notes                                         |
|-------------------------------|---------------------|-----------|-----------------------------------------------|
| `show_channel_central`        | boolean             | false     | Dialog visibility                             |
| `channel_central_tab`         | string              | "general" | Active tab: general/modes/bans/ban_ex/invite_ex |
| `channel_central_channel`     | string \| nil       | nil       | Which channel the dialog is showing           |
| `channel_central_state`       | map \| nil          | nil       | Cached channel state from Server.get_state    |
| `channel_central_ban_selected`| string \| nil       | nil       | Selected ban in bans tab                      |
| `channel_central_be_selected` | string \| nil       | nil       | Selected ban exception                        |
| `channel_central_ie_selected` | string \| nil       | nil       | Selected invite exception                     |
| `show_cc_add_ban_dialog`      | boolean             | false     | Add ban sub-dialog                            |
| `show_cc_add_ban_ex_dialog`   | boolean             | false     | Add ban exception sub-dialog                  |
| `show_cc_add_invite_ex_dialog`| boolean             | false     | Add invite exception sub-dialog               |
| `cc_modes_form`               | map                 | %{}       | Pending mode changes before Apply             |
| `cc_topic_form`               | string              | ""        | Pending topic text                            |

## User-Initiated Events (phx-click / phx-submit)

### Dialog Lifecycle

| Event                          | Params                        | Action                                          |
|--------------------------------|-------------------------------|-------------------------------------------------|
| `open_channel_central`         | `%{"channel" => name}`        | Fetch state, open dialog for channel            |
| `close_channel_central`        | —                             | Close dialog, reset all CC assigns              |
| `channel_central_tab`          | `%{"tab" => tab_name}`        | Switch active tab                               |

### General Tab (Topic)

| Event                          | Params                        | Action                                          |
|--------------------------------|-------------------------------|-------------------------------------------------|
| `cc_set_topic`                 | `%{"topic" => text}`          | Call Server.set_topic, update state              |

### Modes Tab

| Event                          | Params                        | Action                                          |
|--------------------------------|-------------------------------|-------------------------------------------------|
| `cc_apply_modes`               | `%{"modes" => map}`           | Compute diff, call Server.set_mode for changes   |

### Bans Tab

| Event                          | Params                        | Action                                          |
|--------------------------------|-------------------------------|-------------------------------------------------|
| `cc_ban_select`                | `%{"nickname" => nick}`       | Set selected ban                                |
| `cc_open_add_ban`              | —                             | Show add ban sub-dialog                         |
| `cc_close_add_ban`             | —                             | Hide add ban sub-dialog                         |
| `cc_add_ban`                   | `%{"nickname" => nick}`       | Call Server.ban, refresh state                   |
| `cc_remove_ban`                | —                             | Call Server.unban (selected), refresh state       |

### Ban Exceptions Tab

| Event                          | Params                        | Action                                          |
|--------------------------------|-------------------------------|-------------------------------------------------|
| `cc_ban_ex_select`             | `%{"nickname" => nick}`       | Set selected ban exception                      |
| `cc_open_add_ban_ex`           | —                             | Show add ban exception sub-dialog               |
| `cc_close_add_ban_ex`          | —                             | Hide add ban exception sub-dialog               |
| `cc_add_ban_exception`         | `%{"nickname" => nick}`       | Call Server.add_ban_exception, refresh state      |
| `cc_remove_ban_exception`      | —                             | Call Server.remove_ban_exception, refresh state   |

### Invite Exceptions Tab

| Event                          | Params                        | Action                                          |
|--------------------------------|-------------------------------|-------------------------------------------------|
| `cc_invite_ex_select`          | `%{"nickname" => nick}`       | Set selected invite exception                   |
| `cc_open_add_invite_ex`        | —                             | Show add invite exception sub-dialog            |
| `cc_close_add_invite_ex`       | —                             | Hide add invite exception sub-dialog            |
| `cc_add_invite_exception`      | `%{"nickname" => nick}`       | Call Server.add_invite_exception, refresh state   |
| `cc_remove_invite_exception`   | —                             | Call Server.remove_invite_exception, refresh state |

## Server-Initiated Events (handle_info)

These are PubSub messages received while the Channel Central dialog is open:

| Message Pattern                            | Action                                       |
|--------------------------------------------|----------------------------------------------|
| `{:topic_changed, %{channel: ch, ...}}`    | If ch == dialog channel, refresh topic display |
| `{:mode_changed, %{channel: ch, ...}}`     | If ch == dialog channel, refresh modes display |
| `{:user_banned, %{...}}`                   | Refresh bans list                            |
| `{:user_joined, %{...}}`                   | Refresh member count                         |
| `{:user_left, %{...}}`                     | Refresh member count                         |
| `{:ban_exception_added, %{channel: ch}}`   | Refresh ban exceptions list                  |
| `{:ban_exception_removed, %{channel: ch}}` | Refresh ban exceptions list                  |
| `{:invite_exception_added, %{channel: ch}}`  | Refresh invite exceptions list             |
| `{:invite_exception_removed, %{channel: ch}}`| Refresh invite exceptions list             |

**Refresh strategy**: On each relevant PubSub event, call `Server.get_state(channel)` and update `channel_central_state` assign. LiveView re-renders the dialog component with new data.

## Component Interface

### ChannelCentralDialog

```elixir
attr :visible, :boolean, required: true
attr :channel_state, :map, default: nil
attr :active_tab, :string, default: "general"
attr :operator, :boolean, default: false
attr :ban_selected, :string, default: nil
attr :be_selected, :string, default: nil
attr :ie_selected, :string, default: nil
attr :show_add_ban_dialog, :boolean, default: false
attr :show_add_ban_ex_dialog, :boolean, default: false
attr :show_add_invite_ex_dialog, :boolean, default: false
attr :cc_modes_form, :map, default: %{}
```
